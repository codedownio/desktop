{ lib

, bootstrapNixpkgs
, nixBinDir
, certBundle
, termInfo
, runnerBinDir

, rootDir ? "CODEDOWN_ROOT"
, optionOverrides ? {}

, frontend
, templates
}:

lib.generators.toJSON {} ({
  port = 0;
  mode = { tag = "raw"; };
  disable_auth = true;
  index_store_configs = [];
  sandbox_store_providers = [{
    name = "host-local";
    display_name = "Host local sandbox store provider";
    description = "Store provider on the Docker host";
    provider = {
      tag = "local";
      path = "${rootDir}/local_sandboxes";
    };
  }];
  package_store_configs = [{
    name = "default";
    display_name = "Default";
    description = "Default package store config";
    config = {
      tag = "preexisting";
      nix_path = "/nix";
      nix_store_path = "/nix/store";
      nix_bin_dir = nixBinDir;
      cert_bundle = certBundle;
      term_info = termInfo;
      runner_bin_dir = runnerBinDir;
      bootstrap_nixpkgs = { path = bootstrapNixpkgs; };
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
    };
    store = "default";
  }];
  server_root = "${rootDir}/server_root";
  database = {
    type = "sqlite";
    path = "${rootDir}/db.sqlite";
  };
  app_dir = {
    tag = "built_in";
    contents = "${frontend}";
  };
  session_token_signing_key = "";
  startup_jobs = [
    {
      tag = "sync_templates";
      to_namespace = "templates";
      directory = templates;
    }
    { tag = "prune_missing_runners"; }
  ];
} // optionOverrides)
