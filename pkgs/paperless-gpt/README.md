# paperless-gpt

Linux package (`x86_64-linux`, `aarch64-linux`) of
<https://github.com/icereed/paperless-gpt>. Builds the web UI and embeds it in
the Go executable. PDF rendering uses upstream's embedded
PDFium WebAssembly module; no external PDF renderer is required.

From the repository root:

```sh
nix build .#paperless-gpt
nix build .#paperless-gpt.tests.smoke
```

The package build runs the Go unit tests. The smoke test uses a local mock
Paperless API to check startup, the embedded web UI, template installation,
SQLite initialization and PDF rendering. It does not use real documents,
credentials or LLM services.

## Runtime

Run `paperless-gpt` in a **writable, persistent working directory**. Upstream
stores `config/`, `prompts/` (including workflows) and `db/` relative to it.
A systemd service should set `WorkingDirectory` to its state directory.
The package does not create or enable a service.

Configure the connection with `PAPERLESS_BASE_URL`, `PAPERLESS_API_TOKEN`,
`LLM_PROVIDER`, `LLM_MODEL` and the chosen provider's credentials. For OCR,
also configure the OCR provider / vision model as described in the upstream
README. Keep credentials outside the Nix store.

**There is no built-in authentication.** Set `LISTEN_INTERFACE=127.0.0.1:8080`
and put the service behind an authenticating reverse proxy before exposing it.

The executable wrapper supplies these defaults (explicit environment values
still take precedence):

- `GIN_MODE=release`.
- `PAPERLESS_GPT_DEFAULT_PROMPTS_DIR`: packaged default templates. This is a
  packaging patch; editable templates remain in the working directory.
- `TIKTOKEN_CACHE_DIR`: packaged token encodings, avoiding runtime downloads
  even when using a local LLM.

Settings saved through the upstream UI may override its environment defaults;
see upstream documentation for the precedence of individual settings.
