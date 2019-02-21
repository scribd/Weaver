# Migration from v0.11.+ to v0.12.1+

Weaver 0.12.0 comes with several breaking changes.

## Renaming of commands

The command `generate` has been renamed to `swift`.

## Renaming of parameters

Parameters are now using a more unix style. For example `--input_path` became `--input-path`.

## New `swift` command parameters

The `swift` command has new parameters.

```bash
$ weaver swift --help
Usage:

    $ weaver swift

Options:
    --project-path - Project's directory.
    --config-path - Configuration path.
    --output-path - Where the swift files will be generated.
    --template-path - Custom template path.
    --unsafe
    --single-output
    --input-path - Paths to input files.
    --ignored-path - Paths to ignore.
    --recursive-off
```

See the [documentation](https://github.com/scribd/Weaver#generate-swift-files) for details.

## Build Phase

With 0.11.+:

The command to add to the build phase looked like the following:

```bash
weaver generate --output_path ${SOURCE_ROOT}/output/path `find ${SOURCE_ROOT} -name '*.swift' | xargs -0`
```

With 0.12.1+:

This build phase should now be written like the following:

```bash
weaver swift --project-path $PROJECT_DIR/$PROJECT_NAME --output-path output/relative/path
```
