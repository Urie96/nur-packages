{ pkgs }:
let

  lib = pkgs.lib;

  mkSkill =
    skillDir: package:
    let
      name = if package == null then builtins.baseNameOf (toString skillDir) else lib.getName package;

      linkScripts = lib.optionalString (package != null) ''
        ln -sfn ${package}/bin $out/scripts
      '';
    in
    pkgs.runCommand "skill-${name}" { } ''
      mkdir -p $out
      cp -r ${skillDir}/. $out/
      ${linkScripts}
    '';

  callPackage = path: extra: pkgs.callPackage path (extra // { inherit mkSkill; });

  pycall = path: extra: pkgs.python3.pkgs.callPackage path (extra // { inherit mkSkill; });

  skills = {
    tmux = callPackage ./tmux { };
    music-assistant-cli = pycall ./music-assistant-cli { };
    context7-cli = pycall ./context7-cli { };
  }
  // (
    let
      mattpocock-skills = pkgs.fetchFromGitHub {
        owner = "mattpocock";
        repo = "skills";
        rev = "v1.2.3";
        hash = "sha256-I/EXHGW92nXz6JCLp8SKGgzXrbbUTkLAfxv8bc/ThwQ=";
      };
    in

    builtins.listToAttrs (
      builtins.map
        (
          path:
          let
            name = builtins.baseNameOf (builtins.unsafeDiscardStringContext path);
          in
          {
            inherit name;
            value = mkSkill path null;
          }
        )
        [
          "${mattpocock-skills}/skills/productivity/handoff"
          "${mattpocock-skills}/skills/productivity/teach"
          "${mattpocock-skills}/skills/productivity/writing-for-agents"
          "${mattpocock-skills}/skills/productivity/grilling"
        ]
    )
  );
in
skills
// {
  all = pkgs.linkFarm "all-skills" (
    builtins.map (name: {
      inherit name;
      path = skills.${name};
    }) (builtins.attrNames skills)
  );
}
