load("//ruby/private:providers.bzl", "get_transitive_srcs")

_SH_SCRIPT = "{binary} {args} $@"

# We have to explicitly set PATH on Windows because bundler
# binstubs rely on calling Ruby available globally.
# https://github.com/rubygems/rubygems/issues/3381#issuecomment-645026943

_CMD_BINARY_SCRIPT = """
@set PATH={toolchain_bindir};%PATH%
@call {binary}.cmd {args} %*
"""

# Calling ruby.exe directly throws strange error so we rely on PATH instead.

_CMD_RUBY_SCRIPT = """
@set PATH={toolchain_bindir};%PATH%
@ruby {args} %*
"""

def generate_rb_binary_script(ctx, binary, args):
    windows_constraint = ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]
    is_windows = ctx.target_platform_has_constraint(windows_constraint)
    toolchain = ctx.toolchains["@rules_ruby//ruby:toolchain_type"]
    toolchain_bindir = toolchain.bindir

    if binary:
        binary_path = binary.path
    else:
        binary_path = toolchain.ruby.path

    if is_windows:
        binary_path = binary_path.replace("/", "\\")
        script = ctx.actions.declare_file("{}.rb.cmd".format(ctx.label.name))
        toolchain_bindir = toolchain_bindir.replace("/", "\\")
        if binary:
            template = _CMD_BINARY_SCRIPT
        else:
            template = _CMD_RUBY_SCRIPT
    else:
        script = ctx.actions.declare_file("{}.rb.sh".format(ctx.label.name))
        template = _SH_SCRIPT

    args = " ".join(args)
    args = ctx.expand_location(args)

    ctx.actions.write(
        output = script,
        is_executable = True,
        content = template.format(
            args = args,
            binary = binary_path,
            toolchain_bindir = toolchain_bindir,
        ),
    )

    return script

def rb_binary_impl(ctx):
    script = generate_rb_binary_script(ctx, ctx.executable.main, ctx.attr.args)
    transitive_srcs = get_transitive_srcs(ctx.files.srcs, ctx.attr.deps).to_list()
    if not ctx.attr.main:
        transitive_srcs.append(ctx.toolchains["@rules_ruby//ruby:toolchain_type"].ruby)
    runfiles = ctx.runfiles(transitive_srcs)

    return [DefaultInfo(executable = script, runfiles = runfiles)]

rb_binary = rule(
    implementation = rb_binary_impl,
    executable = True,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            doc = """
List of Ruby source files used to build the library.
            """,
        ),
        "deps": attr.label_list(
            doc = """
List of other Ruby libraries the target depends on.
            """,
        ),
        "main": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
            doc = """
Ruby script to run. It may also be a binary stub generated by Bundler.
If omitted, it defaults to the Ruby interpreter.

Use a built-in `args` attribute to pass extra arguments to the script.
            """,
        ),
        "_windows_constraint": attr.label(
            default = "@platforms//os:windows",
        ),
    },
    toolchains = ["@rules_ruby//ruby:toolchain_type"],
    doc = """
Runs a Ruby binary.

Suppose you have the following Ruby gem, where `rb_library()` is used
in `BUILD` files to define the packages for the gem.

```output
|-- BUILD
|-- Gemfile
|-- WORKSPACE
|-- gem.gemspec
`-- lib
    |-- BUILD
    |-- gem
    |   |-- BUILD
    |   |-- add.rb
    |   |-- subtract.rb
    |   `-- version.rb
    `-- gem.rb
```

One of the files can be run as a Ruby script:

`lib/gem/version.rb`:
```ruby
module GEM
  VERSION = '0.1.0'
end

puts "Version is: #{GEM::VERSION}" if __FILE__ == $PROGRAM_NAME
```

You can run this script by defining a target:

`lib/gem/BUILD`:
```bazel
load("@rules_ruby//ruby:defs.bzl", "rb_binary", "rb_library")

rb_library(
    name = "version",
    srcs = ["version.rb"],
)

rb_binary(
    name = "print-version",
    args = ["lib/gem/version.rb"],
    deps = [":version"],
)
```

```output
$ bazel run lib/gem:print-version
INFO: Analyzed target //lib/gem:print-version (1 packages loaded, 3 targets configured).
INFO: Found 1 target...
Target //lib/gem:print-version up-to-date:
  bazel-bin/lib/gem/print-version.rb.sh
INFO: Elapsed time: 0.121s, Critical Path: 0.01s
INFO: 4 processes: 4 internal.
INFO: Build completed successfully, 4 total actions
INFO: Build completed successfully, 4 total actions
Version is: 0.1.0
```

You can also run a Ruby binary script available in Gemfile dependencies,
by passing `bin` argument with a path to a Bundler binary stub:

`BUILD`:
```bazel
load("@rules_ruby//ruby:defs.bzl", "rb_binary", "rb_library")

package(default_visibility = ["//:__subpackages__"])

rb_library(
    name = "gem",
    srcs = [
        "Gemfile",
        "Gemfile.lock",
        "gem.gemspec",
    ],
    deps = ["//lib:gem"],
)

rb_binary(
    name = "rubocop",
    args = ["lib"],
    main = "@bundle//:bin/rubocop",
    deps = [
        ":gem",
        "@bundle",
    ],
)
```

```output
$ bazel run :rubocop
INFO: Analyzed target //:rubocop (4 packages loaded, 32 targets configured).
INFO: Found 1 target...
Target //:rubocop up-to-date:
  bazel-bin/rubocop.rb.sh
INFO: Elapsed time: 0.326s, Critical Path: 0.00s
INFO: 2 processes: 2 internal.
INFO: Build completed successfully, 2 total actions
INFO: Build completed successfully, 2 total actions
Inspecting 4 files
....

4 files inspected, no offenses detected
```
    """,
)
