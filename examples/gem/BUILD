load("@aspect_bazel_lib//lib:expand_template.bzl", "expand_template")
load("@aspect_bazel_lib//lib:paths.bzl", "BASH_RLOCATION_FUNCTION")


load(
    "@rules_ruby//ruby:defs.bzl",
    "rb_binary",
    "rb_gem_build",
    "rb_gem_install",
    "rb_gem_push",
    "rb_test",
)

package(default_visibility = ["//:__subpackages__"])

expand_template(
    name = "shell_wrapper",
    template = "wrapper.tpl.sh",
    out = "wrapper.sh",
    substitutions = {
        "@@rlocation_lib@@": BASH_RLOCATION_FUNCTION.replace("$", "$$"),
        "@@rake_binary@@": "$(rlocationpaths :rake)",
    },
    data = [":rake"],
)

sh_test(
    name = "shell_wrapper_test",
    srcs = [":shell_wrapper"],
    deps = ["@bazel_tools//tools/bash/runfiles"],
    data = [":rake"]
)

rb_binary(
    name = "rake",
    main = "@bundle//bin:rake",
    deps = [
        "//lib:gem",
        "@bundle",
    ],
)

rb_test(
    name = "rubocop",
    size = "small",
    timeout = "moderate",  # JRuby startup can be slow
    data = [".rubocop.yml"],
    main = "@bundle//bin:rubocop",
    tags = ["no-sandbox"],
    deps = [
        "//lib:gem",
        "//spec:add",
        "//spec:env",
        "//spec:subtract",
        "//spec:support",
        "@bundle",
    ],
)

rb_gem_build(
    name = "gem-build",
    gemspec = "gem.gemspec",
    deps = ["//lib:gem"],
)

rb_gem_install(
    name = "gem-install",
    gem = ":gem-build",
)

rb_gem_push(
    name = "gem-release",
    gem = ":gem-build",
)
