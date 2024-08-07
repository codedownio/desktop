{ lib
, fetchurl

, bootstrapNixpkgs
, defaultPackageStoreEnv
, staticDocs

, editorBinDir
, editorPath
, frontend
, templates
, runner
}:

lib.generators.toJSON {} {
  port = 0;
  mode = { tag = "raw_electron"; };
  disable_auth = true;
  disable_landing_page = true;
  sandbox_store_providers = [{
    name = "host-local";
    display_name = "Host local sandbox store provider";
    description = "Store provider on the Docker host";
    provider = {
      tag = "local";
      path = "CODEDOWN_ROOT/local_sandboxes";
    };
  }];
  package_store_configs = [{
    name = "default";
    display_name = "Default";
    description = "Default package store config";
    config = {
      tag = "preexisting";
      bootstrap_nixpkgs = bootstrapNixpkgs;
      default_env = defaultPackageStoreEnv;
      nix_path = "/nix";
      store_path = "/nix/store";
      read_only_binds = [
        ["/etc/hosts" "/etc/hosts"]
      ];
    };
  }];
  runner_configs = [{
    name = "default";
    display_name = "Default runner";
    description = "Local runner";
    config = {
      tag = "process";
      runner_executable = "${runner}/bin/codedown-runner";
      # log_dir = "/tmp";
    };
    store = "default"; # Must be a key into the stores
  }];
  templates_dir = templates;
  imports_root = "CODEDOWN_ROOT/imports";
  database = { type = "sqlite"; path = "CODEDOWN_ROOT/db.sqlite"; };
  email_from = "admin@codedown.io";
  email_sender = { type = "null"; };
  app_dir = "${frontend}";
  static_docs_dir = staticDocs;
  sandboxes_root = "CODEDOWN_ROOT/sandboxes";
  package_stores_root = "CODEDOWN_ROOT/local_stores";
  runners_root = "CODEDOWN_ROOT/local_runners";
  session_token_signing_key = "";
  editor_bin_dir = "${editorBinDir}/bin/";
  editor_path = editorPath;
  startup_jobs = [
    { tag = "sync_templates"; }
    { tag = "prune_missing_runners"; }
  ];
}
