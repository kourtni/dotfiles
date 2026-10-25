# Validate before returning any field, so Nix's lazy evaluation cannot hide
# other missing settings behind the first attribute a module happens to read.
{ requireSystem ? false }:
raw:
let
  nonEmptyString = value: builtins.isString value && builtins.match ".*[^[:space:]].*" value != null;
  config = { uid = null; windowsUsername = ""; } // raw;
  git = if builtins.isAttrs (raw.git or null) then raw.git else {};
  check = name: valid: expected:
    if valid then [] else [ "${name}: ${expected}" ];
  errors =
    check "username" (nonEmptyString (raw.username or null)) "required non-empty string"
    ++ check "homeDirectory"
      (nonEmptyString (raw.homeDirectory or null) && builtins.substring 0 1 raw.homeDirectory == "/")
      "required absolute path string"
    ++ check "stateVersion" (nonEmptyString (raw.stateVersion or null)) "required non-empty string"
    ++ check "git.name" (nonEmptyString (git.name or null)) "required non-empty string"
    ++ check "git.email" (nonEmptyString (git.email or null)) "required non-empty string"
    ++ check "system"
      ((!requireSystem && !(raw ? system)) || builtins.elem (raw.system or null) [
        "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"
      ])
      "required for NixOS; when supplied, must be x86_64-linux, aarch64-linux, x86_64-darwin, or aarch64-darwin"
    ++ check "uid" (config.uid == null || (builtins.isInt config.uid && config.uid >= 0))
      "must be null or a non-negative integer"
    ++ check "windowsUsername" (builtins.isString config.windowsUsername) "must be a string (empty disables the configured Windows user path)";
  help = "Edit your external user-config.nix; see user-config.nix.template and README.md. No settings were changed.";
in
if !builtins.isAttrs raw then
  throw "Invalid user-config.nix: expected an attribute set. ${help}"
else if errors != [] then
  throw ("Invalid user-config.nix:\n  - " + builtins.concatStringsSep "\n  - " errors + "\n" + help)
else config
