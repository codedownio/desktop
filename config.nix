{ lib

, bootstrapNixpkgs
, defaultPackageStoreEnv
, staticDocs

, frontend
, templates
}:

lib.generators.toJSON {} {
  port = 0;
  mode = { tag = "raw"; };
  disable_auth = true;
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
      gc_roots_dir = "CODEDOWN_ROOT/gc_roots";
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
      # log_dir = "/tmp";
    };
    store = "default"; # Must be a key into the stores
  }];
  templates_dir = templates;
  server_root = "CODEDOWN_ROOT/server_root";
  database = { type = "sqlite"; path = "CODEDOWN_ROOT/db.sqlite"; };
  app_dir = "${frontend}";
  static_docs_dir = staticDocs;
  session_token_signing_key = "";
  startup_jobs = [
    { tag = "sync_templates"; }
    { tag = "prune_missing_runners"; }
  ];
}
