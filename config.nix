{ lib
, fetchurl

, bootstrapNixpkgs
, defaultPackageStoreEnv
, staticDocs

, editor
, frontend
, templates
, runner
}:

lib.generators.toJSON {} {
  port = 8585;
  mode = { tag = "raw_electron"; };
  disable_auth = true;
  disable_landing_page = true;
  sandbox_store_providers = [{
    name = "host-local";
    display_name = "Host local sandbox store provider";
    description = "Store provider on the Docker host";
    provider = {
      tag = "local";
      path = "/nix";
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
        ["/etc/resolv.conf" "/etc/resolv.conf"]
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
  templates = {
    dir = templates;
    sections = [{
      display_name = "Basic";
      templates = [{
        tag = "sandbox";
        name = "Python";
        sandbox_name = {
          namespace = "templates";
          name = "python";
        };
      }];
    }];
  };
  database = { type = "sqlite"; path = "CODEDOWN_ROOT/db.sqlite"; };
  email_from = "admin@codedown.io";
  email_sender = { type = "null"; };
  app_dir = "${frontend}";
  static_docs_dir = staticDocs;
  sandboxes_root = "CODEDOWN_ROOT/sandboxes";
  package_stores_root = "CODEDOWN_ROOT/local_stores";
  runners_root = "CODEDOWN_ROOT/local_runners";
  session_token_signing_key = "";
  editor_bin_dir = "${editor}/bin";
}
