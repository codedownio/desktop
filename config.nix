{ lib
, fetchurl

, templates
, editor
, runner
}:

lib.generators.toJSON {} {
  port = 80;
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
      tag = "sandboxed";
      template = "/store-template";
      bootstrap_nixpkgs = "/bootstrap-nixpkgs";
      default_env = "/nix/default-env";
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
      log_dir = "/tmp";
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
  database = { type = "sqlite"; path = "/conf/sqlite.db"; };
  email_from = "admin@codedown.io";
  email_sender = { type = "null"; };
  app_dir = "/srv/frontend";
  static_docs_dir = "/srv/static_docs";
  sandboxes_root = "/sandboxes";
  package_stores_root = "/local_stores";
  runners_root = "/local_runners";
  work_dir = "/work";
  session_token_signing_key = "";
  editor_bin_dir = "${editor}/bin";
}
