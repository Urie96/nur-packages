// Command sops-render 用 sops 库解密 secrets，并把模板里的
// <SOPS:NAME:PLACEHOLDER> 占位符替换成明文写入指定文件。
//
// 另外提供 --list-keys：不解密，只解析加密文件的结构，把扁平化后的 key 名以
// JSON 数组输出（sops 自己没这个命令）。sops 只加密 value，key 是明文，
// 所以这一步不需要私钥，可以给 Nix 在 eval 阶段生成占位符用。
//
// 设计要点（见 ../handoff-sops-wrapper-design.md）：
//   - 直接 import github.com/getsops/sops/v3/decrypt，不 fork sops 进程。
//     age 私钥来源（SOPS_AGE_KEY / SOPS_AGE_KEY_FILE / SOPS_AGE_KEY_CMD /
//     SSH 私钥 / 默认 keys.txt）与 sops CLI 完全一致，不需要 .sops.yaml。
//   - 明文文件在解密之前就删除：解密失败时不会留下上一轮的旧明文。
//   - 所有模板先在内存里渲染完，再统一写临时文件、统一 rename，
//     读取方不会看到写了一半的文件。
package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/getsops/sops/v3/decrypt"
	"go.yaml.in/yaml/v3"
)

// 私钥都没通过环境变量给出时的兜底路径（sops-nix 的约定）。
const defaultKeyFile = "/var/lib/sops-nix/key.txt"

const usageText = `用法: sops-render [选项] -s SECRETS -m TEMPLATE OUTPUT [-m TEMPLATE OUTPUT ...]

用 sops 解密 secrets，并把模板渲染成明文文件。解密由当前进程直接完成，
不会产生常驻的 sops 进程。

必填:
  -s, --secrets FILE    sops 加密的 secrets 文件（yaml 或 json）
  -m, --map TEMPLATE OUTPUT
                        模板文件，以及渲染后写入的明文文件路径。
                        可重复多次。

选项:
      --format json|yaml   secrets 文件格式，默认按扩展名判断
      --list-keys          不解密，只解析结构，把扁平化后的 key 名以 JSON
                           数组打印到 stdout（加密文件里的 key 本来就是明文）
      --key-file FILE      用 FILE 作为 age 私钥（设置 SOPS_AGE_KEY_FILE）
      --key-cmd CMD        执行 CMD，用其输出作为 age 私钥
                           （设置 SOPS_AGE_KEY_CMD，例如复用 ssh key）
      --mode MODE          明文文件权限，默认 0600
  -p, --parents            目标目录不存在时自动创建（权限 0700）
  -h, --help               显示帮助

私钥来源沿用 sops 的规则：环境变量 SOPS_AGE_KEY / SOPS_AGE_KEY_FILE /
SOPS_AGE_KEY_CMD / SOPS_AGE_SSH_PRIVATE_KEY_* 会原样传给 sops 库。这些都没
设置、且 /var/lib/sops-nix/key.txt 存在时，会把它当作 SOPS_AGE_KEY_FILE。

占位符形式是 <SOPS:NAME:PLACEHOLDER>，例如 <SOPS:db_password:PLACEHOLDER>。
名字大小写精确匹配，不做大小写折叠。secrets 文件里嵌套的 key 用下划线拼平，
例如 database.password 对应 <SOPS:database_password:PLACEHOLDER>；列表值不支持。
占位符对应的 secret 缺失时报错退出，而不是渲染成空字符串。
模板里其它 $ 用法（nginx 的 $remote_addr、shell 的 ${VAR} 等）原样保留。
`

type mapping struct {
	template string
	output   string
}

type options struct {
	secrets  string
	format   string
	maps     []mapping
	mode     os.FileMode
	parents  bool
	listKeys bool
	keyFile  string
	keyCmd   string
}

// usageError 表示命令行用法错误，退出码为 2。
type usageError struct{ msg string }

func (e usageError) Error() string { return e.msg }

func usagef(format string, a ...any) error {
	return usageError{fmt.Sprintf(format, a...)}
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "sops-render: %v\n", err)
		var ue usageError
		if errors.As(err, &ue) {
			fmt.Fprintln(os.Stderr)
			fmt.Fprint(os.Stderr, usageText)
			os.Exit(2)
		}
		os.Exit(1)
	}
}

func run(args []string) error {
	opts, err := parseArgs(args)
	if err != nil {
		return err
	}

	if opts.listKeys {
		raw, err := os.ReadFile(opts.secrets)
		if err != nil {
			return fmt.Errorf("读取 %s 失败: %w", opts.secrets, err)
		}
		names, err := listKeyNames(raw, opts.format)
		if err != nil {
			return err
		}
		out, err := json.Marshal(names)
		if err != nil {
			return err
		}
		fmt.Println(string(out))
		return nil
	}

	// 模板先读进内存：参数/文件有问题时不要动已有的明文文件。
	templates := make([][]byte, len(opts.maps))
	for i, m := range opts.maps {
		b, err := os.ReadFile(m.template)
		if err != nil {
			return fmt.Errorf("读取模板失败: %w", err)
		}
		templates[i] = b
	}

	applyKeySource(opts)

	// 防止把加密文件本身当成输出路径删掉。
	if secretsInfo, err := os.Stat(opts.secrets); err == nil {
		for _, m := range opts.maps {
			if outInfo, err := os.Stat(m.output); err == nil && os.SameFile(outInfo, secretsInfo) {
				return fmt.Errorf("输出路径 %s 就是 secrets 文件本身", m.output)
			}
		}
	}

	if opts.parents {
		for _, m := range opts.maps {
			dir := filepath.Dir(m.output)
			if err := os.MkdirAll(dir, 0o700); err != nil {
				return fmt.Errorf("创建目录 %s 失败: %w", dir, err)
			}
		}
	}

	// 陈旧明文必须在解密之前删掉：解密失败时下面任何一步都不会执行，
	// 放在后面的 rm 没有机会运行。
	for _, m := range opts.maps {
		if err := os.Remove(m.output); err != nil && !errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("删除旧文件 %s 失败: %w", m.output, err)
		}
	}

	cleartext, err := decrypt.File(opts.secrets, opts.format)
	if err != nil {
		return fmt.Errorf("解密 %s 失败: %w", opts.secrets, err)
	}

	secrets, err := parseSecrets(cleartext, opts.format)
	if err != nil {
		return err
	}

	results := make([]renderedFile, len(opts.maps))
	for i, m := range opts.maps {
		data, err := render(templates[i], secrets)
		if err != nil {
			return fmt.Errorf("渲染 %s 失败: %w", m.template, err)
		}
		results[i] = renderedFile{output: m.output, data: data}
	}

	return commitAll(results, opts.mode)
}

func parseArgs(args []string) (options, error) {
	opts := options{mode: 0o600}

	for len(args) > 0 {
		arg := args[0]
		switch arg {
		case "-s", "--secrets":
			if len(args) < 2 {
				return opts, usagef("%s 需要一个参数", arg)
			}
			opts.secrets = args[1]
			args = args[2:]
		case "-m", "--map":
			if len(args) < 3 {
				return opts, usagef("%s 需要 TEMPLATE 和 OUTPUT 两个参数", arg)
			}
			opts.maps = append(opts.maps, mapping{template: args[1], output: args[2]})
			args = args[3:]
		case "--format":
			if len(args) < 2 {
				return opts, usagef("%s 需要一个参数", arg)
			}
			opts.format = args[1]
			args = args[2:]
		case "--key-file":
			if len(args) < 2 {
				return opts, usagef("%s 需要一个参数", arg)
			}
			opts.keyFile = args[1]
			args = args[2:]
		case "--key-cmd":
			if len(args) < 2 {
				return opts, usagef("%s 需要一个参数", arg)
			}
			opts.keyCmd = args[1]
			args = args[2:]
		case "--mode":
			if len(args) < 2 {
				return opts, usagef("%s 需要一个参数", arg)
			}
			mode, err := strconv.ParseUint(args[1], 8, 32)
			if err != nil {
				return opts, usagef("无效的 --mode %q: %v", args[1], err)
			}
			opts.mode = os.FileMode(mode)
			args = args[2:]
		case "-p", "--parents":
			opts.parents = true
			args = args[1:]
		case "--list-keys":
			opts.listKeys = true
			args = args[1:]
		case "-h", "--help":
			fmt.Print(usageText)
			os.Exit(0)
		case "--":
			args = args[1:]
			goto done
		default:
			if strings.HasPrefix(arg, "-") {
				return opts, usagef("未知选项: %s", arg)
			}
			return opts, usagef("多余的参数: %s", arg)
		}
	}

done:
	if len(args) > 0 {
		return opts, usagef("多余的参数: %s", strings.Join(args, " "))
	}
	if opts.secrets == "" {
		return opts, usagef("缺少 -s/--secrets")
	}
	if opts.listKeys {
		if len(opts.maps) > 0 {
			return opts, usagef("--list-keys 不能和 -m/--map 一起用")
		}
	} else if len(opts.maps) == 0 {
		return opts, usagef("至少需要一个 -m/--map TEMPLATE OUTPUT")
	}

	format := opts.format
	if format == "" {
		var err error
		format, err = detectFormat(opts.secrets)
		if err != nil {
			return opts, err
		}
	}
	if format != "json" && format != "yaml" {
		return opts, usagef("不支持的 --format %q（只支持 json/yaml）", format)
	}
	opts.format = format

	return opts, nil
}

func detectFormat(path string) (string, error) {
	switch strings.ToLower(filepath.Ext(path)) {
	case ".json":
		return "json", nil
	case ".yaml", ".yml":
		return "yaml", nil
	default:
		return "", usagef("无法从扩展名判断 %s 的格式，请用 --format json|yaml", path)
	}
}

// applyKeySource 把命令行给出的私钥来源写回环境变量，这样 sops 库的
// age keysource 能像 sops CLI 一样找到它。
func applyKeySource(opts options) {
	if opts.keyFile != "" {
		os.Setenv("SOPS_AGE_KEY_FILE", opts.keyFile)
	}
	if opts.keyCmd != "" {
		os.Setenv("SOPS_AGE_KEY_CMD", opts.keyCmd)
	}
	if os.Getenv("SOPS_AGE_KEY") != "" ||
		os.Getenv("SOPS_AGE_KEY_FILE") != "" ||
		os.Getenv("SOPS_AGE_KEY_CMD") != "" {
		return
	}
	if _, err := os.Stat(defaultKeyFile); err == nil {
		os.Setenv("SOPS_AGE_KEY_FILE", defaultKeyFile)
	}
}

// decodeDocument 把 yaml/json 文本解析成通用的 map/slice/scalar 结构。
func decodeDocument(data []byte, format string) (any, error) {
	var root any
	switch format {
	case "json":
		dec := json.NewDecoder(bytes.NewReader(data))
		dec.UseNumber() // 避免大整数/精度被 float64 破坏
		if err := dec.Decode(&root); err != nil {
			return nil, fmt.Errorf("解析 json 失败: %w", err)
		}
	case "yaml":
		if err := yaml.Unmarshal(data, &root); err != nil {
			return nil, fmt.Errorf("解析 yaml 失败: %w", err)
		}
	default:
		return nil, fmt.Errorf("不支持的格式 %q", format)
	}
	return root, nil
}

func parseSecrets(data []byte, format string) (map[string]string, error) {
	root, err := decodeDocument(data, format)
	if err != nil {
		return nil, err
	}

	secrets := map[string]string{}
	if err := flatten("", root, secrets, false); err != nil {
		return nil, err
	}
	return secrets, nil
}

// listKeyNames 解析（不解密）文件结构，返回扁平化后的 key 名。
// sops 只加密 value，所以加密文件和明文的结构完全相同，key 名不需要私钥就能拿到。
func listKeyNames(data []byte, format string) ([]string, error) {
	root, err := decodeDocument(data, format)
	if err != nil {
		return nil, err
	}

	// 去掉 sops 自己的元数据块（里面有 age/pgp 条目和 list，对它报错没意义）。
	switch m := root.(type) {
	case map[string]any:
		delete(m, "sops")
	case map[any]any:
		delete(m, "sops")
	}

	names := map[string]string{}
	if err := flatten("", root, names, true); err != nil {
		return nil, err
	}

	out := make([]string, 0, len(names))
	for name := range names {
		out = append(out, name)
	}
	sort.Strings(out)
	return out, nil
}

// flatten 把嵌套的 map 用下划线拼平成 NAME=VALUE，方便模板用 ${NAME} 引用。
// skipLists 为 true 时忽略列表值（--list-keys 用），否则列表会报错。
func flatten(prefix string, value any, out map[string]string, skipLists bool) error {
	switch v := value.(type) {
	case map[string]any:
		for _, key := range sortedKeys(v) {
			if err := flatten(join(prefix, key), v[key], out, skipLists); err != nil {
				return err
			}
		}
	case map[any]any:
		for _, key := range sortedAnyKeys(v) {
			if err := flatten(join(prefix, fmt.Sprint(key)), v[key], out, skipLists); err != nil {
				return err
			}
		}
	case nil:
		return set(out, prefix, "")
	case []any, []string:
		if skipLists {
			return nil
		}
		if prefix == "" {
			return errors.New("secrets 文件的顶层必须是 map")
		}
		return fmt.Errorf("key %q 是列表，不支持", prefix)
	default:
		return set(out, prefix, scalarString(v))
	}
	return nil
}

func join(prefix, key string) string {
	if prefix == "" {
		return key
	}
	return prefix + "_" + key
}

func set(out map[string]string, name, value string) error {
	if name == "" {
		return errors.New("secrets 文件的顶层必须是 map")
	}
	if old, ok := out[name]; ok {
		return fmt.Errorf("key %q 与已有的 %q 冲突（嵌套 key 会用下划线拼平）", name, old)
	}
	out[name] = value
	return nil
}

func scalarString(v any) string {
	switch t := v.(type) {
	case string:
		return t
	case bool:
		return strconv.FormatBool(t)
	case int:
		return strconv.Itoa(t)
	case int64:
		return strconv.FormatInt(t, 10)
	case uint64:
		return strconv.FormatUint(t, 10)
	case float64:
		return strconv.FormatFloat(t, 'g', -1, 64)
	case json.Number:
		return t.String()
	case time.Time:
		return t.Format(time.RFC3339)
	default:
		return fmt.Sprint(v)
	}
}

func sortedKeys(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func sortedAnyKeys(m map[any]any) []any {
	keys := make([]any, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool { return fmt.Sprint(keys[i]) < fmt.Sprint(keys[j]) })
	return keys
}

// 只认 <SOPS:NAME:PLACEHOLDER>，模板里其它 $ 用法（nginx 的 $remote_addr 等）完全不碰。
// 名字大小写精确匹配，不做大小写折叠。
var placeholderRe = regexp.MustCompile(`<SOPS:([A-Za-z_][A-Za-z0-9_]*):PLACEHOLDER>`)

// render 做字面替换：secret 里的 $、&、反引号、换行都不会被二次解释。
func render(template []byte, secrets map[string]string) ([]byte, error) {
	var missing []string
	seen := map[string]bool{}

	var out []byte
	last := 0
	for _, loc := range placeholderRe.FindAllSubmatchIndex(template, -1) {
		out = append(out, template[last:loc[0]]...)
		name := string(template[loc[2]:loc[3]])
		value, ok := secrets[name]
		if !ok {
			if !seen[name] {
				seen[name] = true
				missing = append(missing, name)
			}
			out = append(out, template[loc[0]:loc[1]]...)
		} else {
			out = append(out, value...)
		}
		last = loc[1]
	}
	out = append(out, template[last:]...)

	if len(missing) > 0 {
		sort.Strings(missing)
		return nil, fmt.Errorf("缺少 secret: %s", strings.Join(missing, ", "))
	}
	return out, nil
}

type renderedFile struct {
	output string
	data   []byte
}

type stagedFile struct {
	tmp    string
	output string
}

// commitAll 先把所有内容写进目标目录的临时文件（权限已设好），
// 再统一 rename 到目标路径。
func commitAll(results []renderedFile, mode os.FileMode) error {
	staged := make([]stagedFile, 0, len(results))
	cleanup := true
	defer func() {
		if cleanup {
			for _, s := range staged {
				os.Remove(s.tmp)
			}
		}
	}()

	for _, r := range results {
		tmp, err := stage(r.output, r.data, mode)
		if err != nil {
			return err
		}
		staged = append(staged, stagedFile{tmp: tmp, output: r.output})
	}

	for _, s := range staged {
		if err := os.Rename(s.tmp, s.output); err != nil {
			return fmt.Errorf("写入 %s 失败: %w", s.output, err)
		}
	}
	cleanup = false
	return nil
}

func stage(output string, data []byte, mode os.FileMode) (string, error) {
	dir := filepath.Dir(output)
	f, err := os.CreateTemp(dir, "."+filepath.Base(output)+".tmp-")
	if err != nil {
		return "", fmt.Errorf("在 %s 创建临时文件失败: %w", dir, err)
	}
	tmp := f.Name()

	if _, err := f.Write(data); err != nil {
		f.Close()
		os.Remove(tmp)
		return "", fmt.Errorf("写 %s 失败: %w", tmp, err)
	}
	if err := f.Chmod(mode); err != nil {
		f.Close()
		os.Remove(tmp)
		return "", fmt.Errorf("chmod %s 失败: %w", tmp, err)
	}
	if err := f.Close(); err != nil {
		os.Remove(tmp)
		return "", fmt.Errorf("关闭 %s 失败: %w", tmp, err)
	}
	return tmp, nil
}
