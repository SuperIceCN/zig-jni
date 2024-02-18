# Zig-JNI

Zig-JNI is a thin wrapper around the Java Native Interface (JNI) for the Zig programming language. It is designed to be a simple and easy-to-use interface for implementing Java native methods in Zig.

Please note that this project is **still in the early stages** of development, and it is **not** yet ready for production use. This project was initially created as a part of another project of mine which provides a write-one-run-anywhere solution for GPGPU programming using java language, and I will continue to improve it as I work on that project.

Since this project is licensed under the MIT license, you are free to use it in your own projects, but please be aware that it is still a work in progress, and it may contain bugs or other issues. If you encounter any problems, please feel free to open an issue or submit a pull request.

## Why Zig?

Zig is a modern, general-purpose programming language with a focus on safety, performance, and simplicity. It is designed to be a better C, and it is a great fit for implementing native methods in Java.  

The important features of Zig, especially for JNI development, are:

- **First-class support for cross-compilation**: Zig can compile code for any platform from any platform, and it can do so with a single command. This makes it easy to build JNI libraries for multiple platforms from a single machine.
- **No runtime**: Zig has no runtime, and it does not require a runtime to be present on the target system. This makes it easy to build small, self-contained JNI libraries that can be easily distributed and used.
- **C & C++ interoperability**: Zig has first-class support for interoperating with C and C++ code, which makes it easy to work with the JNI API and other C libraries.

## Platform Support

| | Linux | Windows | macOS |
| --- | --- | --- | --- |
| x86_64 | ✅ | ✅ | ✅ |
| aarch64 | ✅ | ❓ | ❓ |
| armv7 | ❓ | ❌ | ❌ |

- ✅ Supported
- ❓ Untested, but should work
- ❌ Not supported

## Import the library

**First**, add Zig-JNI to your `build.zig.zon` file (Don't forget to replace `{VERSION}` with the version you want to use) :  

```zon
.{
    .name = "...",
    .version = "...",
    .dependencies = .{
        .JNI = .{
            .url = "https://github.com/SuperIceCN/Zig-JNI/archive/refs/tags/{VERSION}.tar.gz",
        }
    },
}
```

**Second**, Run zig build in your project, and the compiler will instruct you to add a .hash = "..." field next to .url.

**Third**, use the dependency in your `build.zig` :

```zig
pub fn build(b: *std.Build) void {
    // depdencies
    const dep_JNI = b.dependency("JNI", .{}).module("JNI");
    // ...
    artifact.root_module.addImport("jni", dep_JNI); 
    // here artifact is the return value of b.addExecutable / b.addSharedLibrary / b.addStaticLibrary
    // ...
}
```

## Example

Here is a simple example of how to use Zig-JNI to implement a native method in Java:

`com/example/SimpleAdd.java` :  

```java
package com.example;

public class SimpleAdd {
    static {
        System.load("/path/to/shared_librarys.so");
    }

    private static native void add(int a, int b);

    public static void main(String[] args) {
        var a = Integer.parseInt(args[0]);
        var b = Integer.parseInt(args[1]);
        System.out.println("Answer: " + add(a, b));
    }
}
```

`SimpleAdd.zig` :  

```zig
const std = @import("std");
const jni = @import("jni");

pub fn add(cEnv: *jni.cEnv, _: jni.jclass, a: jni.jint, b: jni.jint) callconv(.C) jni.jint {
    return a + b;
}
```

`root.zig` :  

```zig
const jni = @import("jni");

comptime {
    jni.exportJNI("com.example.SimpleAdd", @import("SimpleAdd.zig"));
}
```