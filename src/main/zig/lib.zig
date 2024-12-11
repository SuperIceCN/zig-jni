const std = @import("std");

pub const cjni = @cImport({
    @cInclude("jni.h");
});

pub const cEnv = cjni.JNIEnv;

pub const jint = cjni.jint;
pub const jlong = cjni.jlong;
pub const jbyte = cjni.jbyte;
pub const jboolean = cjni.jboolean;
pub const jchar = cjni.jchar;
pub const jshort = cjni.jshort;
pub const jfloat = cjni.jfloat;
pub const jdouble = cjni.jdouble;
pub const jsize = cjni.jsize;
pub const jobject = cjni.jobject;
pub const jclass = jobject;
pub const jthrowable = jobject;
pub const jstring = jobject;
pub const jarray = jobject;
pub const jbooleanArray = jarray;
pub const jbyteArray = jarray;
pub const jcharArray = jarray;
pub const jshortArray = jarray;
pub const jintArray = jarray;
pub const jlongArray = jarray;
pub const jfloatArray = jarray;
pub const jdoubleArray = jarray;
pub const jobjectArray = jarray;
pub const jweak = jobject;
pub const jvalue = cjni.jvalue;
pub const jfieldID = cjni.jfieldID;
pub const jmethodID = cjni.jmethodID;
pub const jobjectRefType = enum(c_uint) {
    JNIInvalidRefType,
    JNILocalRefType,
    JNIGlobalRefType,
    JNIWeakGlobalRefType,
};

/// Used at releasePrimitiveArrayElements.
pub const jReleasePrimitiveArrayElementsMode = enum(jint) {
    /// For raw-data, release the reference and allow the GC to free the java array.
    /// For buffer-copy, copy back the content and free the buffer.
    JNIDefault,

    /// For raw-data, do nothing (the reference is still alive).
    /// For buffer-copy, copy back the content but do not free the buffer (You can use it multiple times).
    JNICommit,

    /// For raw-data, release the reference and allow the GC to free the java array.
    /// For buffer-copy, free the buffer but do not copy back the content.
    JNIAbort,
};

pub const JNIError = error{
    JNIUnknown,
    JNIThreadDetached,
    JNIInvalidVersion,
    JNIOutOfMemory,
    JNIVMAlreadyCreated,
    JNIInvalidArguments,
};

pub const JNIVersion = enum(jint) {
    JNIInvalidVersion,
    JNI1_1 = cjni.JNI_VERSION_1_1,
    JNI1_2 = cjni.JNI_VERSION_1_2,
    JNI1_4 = cjni.JNI_VERSION_1_4,
    JNI1_6 = cjni.JNI_VERSION_1_6,
    JNI1_8 = cjni.JNI_VERSION_1_8,
    JNI9 = cjni.JNI_VERSION_9,
    JNI10 = cjni.JNI_VERSION_10,
    JNI19 = cjni.JNI_VERSION_19,
    JNI20 = cjni.JNI_VERSION_20,
    JNI21 = cjni.JNI_VERSION_21,
};

pub fn checkError(retCode: jint) JNIError!void {
    if (retCode == cjni.JNI_OK) {
        return;
    }

    return switch (retCode) {
        cjni.JNI_EDETACHED => JNIError.JNIThreadDetached,
        cjni.JNI_EVERSION => JNIError.JNIInvalidVersion,
        cjni.JNI_ENOMEM => JNIError.JNIOutOfMemory,
        cjni.JNI_EEXIST => JNIError.JNIVMAlreadyCreated,
        cjni.JNI_EINVAL => JNIError.JNIInvalidArguments,
        else => JNIError.JNIUnknown,
    };
}

/// Convert a jboolean type to a bool.
pub inline fn jbooleanToBool(b: jboolean) bool {
    return b != 0;
}

/// Convert a bool type to a jboolean.
pub inline fn boolToJboolean(b: bool) jboolean {
    return if (b) 1 else 0;
}

/// Exports all functions with C calling convention from the provided `func_struct` type to be
/// accessible from Java using the JNI.
pub fn exportJNI(comptime class_name: []const u8, comptime func_struct: type) void {
    inline for (@typeInfo(func_struct).@"struct".decls) |decl| {
        const func = comptime @field(func_struct, decl.name);
        const func_type = @TypeOf(func);

        // If it is not a function, skip.
        if (@typeInfo(func_type) != .@"fn") {
            continue;
        }


        // If it is not a function with calling convention .C, skip.
        if (!@typeInfo(func_type).@"fn".calling_convention.eql(.c)) {
            continue;
        }

        const tmp_name: []const u8 = comptime ("Java." ++ class_name ++ "." ++ decl.name);
        var export_name: [tmp_name.len]u8 = undefined;

        @setEvalBranchQuota(30000);

        _ = comptime std.mem.replace(u8, tmp_name, ".", "_", export_name[0..]);

        @export(&func, .{
            .name = export_name[0..],
            .linkage = .strong,
        });
    }
}

/// Returns the number of elements in the given type.
///
/// Examples:
///
/// ```zig
/// const len1 = valueLen(u32); // len1 = 1
/// const len2 = valueLen(void); // len2 = 0
/// const Foo = struct { a: u32, b: f32 };
/// const len3 = valueLen(Foo); // len3 = 2
/// ```
inline fn valueLen(comptime ArgsType: type) comptime_int {
    const args_type_info = @typeInfo(ArgsType);

    return switch (args_type_info) {
        .@"struct" => |s| s.fields.len,
        .@"void" => 0,
        else => 1,
    };
}

/// Converts a tuple or struct of arguments into an array of `jvalue` structs.
///
/// Examples:
///
/// ```zig
/// const args1 = 42;
/// const jvalues1 = toJValues(args1);
///
/// const Args2 = struct { a: i32, b: f64 };
/// const args2 = Args2{ .a = 123, .b = 3.14 };
/// const jvalues2 = toJValues(args2);
/// ```
pub fn toJValues(args: anytype) [valueLen(@TypeOf(args))]jvalue {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);

    if (args_type_info != .@"struct") {
        return switch (ArgsType) {
            jboolean => [1]jvalue{.{ .z = args }},
            jbyte => [1]jvalue{.{ .b = args }},
            jchar => [1]jvalue{.{ .c = args }},
            jshort => [1]jvalue{.{ .s = args }},
            jint => [1]jvalue{.{ .i = args }},
            jlong => [1]jvalue{.{ .j = args }},
            jfloat => [1]jvalue{.{ .f = args }},
            jdouble => [1]jvalue{.{ .d = args }},
            jobject => [1]jvalue{.{ .l = args }},
            i32 => [1]jvalue{.{ .i = @intCast(args) }},
            i64 => [1]jvalue{.{ .j = @intCast(args) }},
            u32 => [1]jvalue{.{ .i = @intCast(args) }},
            u64 => [1]jvalue{.{ .j = @intCast(args) }},
            bool => [1]jvalue{.{ .z = boolToJboolean(args) }},
            else => @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType)),
        };
    }

    const fields = args_type_info.@"struct".fields;
    var output: [fields.len]jvalue = undefined;

    inline for (fields, 0..) |field, i| {
        const value = @field(args, field.name);
        output[i] = switch (field.type) {
            jboolean => .{ .z = value },
            jbyte => .{ .b = value },
            jchar => .{ .c = value },
            jshort => .{ .s = value },
            jint => .{ .i = value },
            jlong => .{ .j = value },
            jfloat => .{ .f = value },
            jdouble => .{ .d = value },
            jobject => .{ .l = value },
            i32 => .{ .i = @intCast(value) },
            i64 => .{ .j = @intCast(value) },
            u32 => .{ .i = @intCast(value) },
            u64 => .{ .j = @intCast(value) },
            bool => .{ .z = boolToJboolean(value) },
            else => @panic("jvalue type not supported"),
        };
    }

    return output;
}

/// JavaVM wrapper.
pub const JavaVM = struct {
    // Raw cjni JavaVM.
    _cJavaVM: ?*cjni.JavaVM = null,

    /// Converts a raw cjni JavaVM to a JavaVM.
    pub inline fn warp(cJavaVM: ?*cjni.JavaVM) JavaVM {
        return JavaVM{ ._cJavaVM = cJavaVM };
    }

    /// Unloads a Java VM and reclaims its resources.
    pub fn destroy(self: *JavaVM) !void {
        return try checkError(self._cJavaVM.?.*.*.DestroyJavaVM.?(self._cJavaVM));
    }

    /// Attaches the current thread to a Java VM.
    pub fn attachCurrentThread(self: *JavaVM, penv: *?*cEnv, args: ?*anyopaque) !void {
        return try checkError(self._cJavaVM.?.*.*.AttachCurrentThread.?(self._cJavaVM, @ptrCast(penv), args));
    }

    /// Detaches the current thread from a Java VM. All Java monitors held by this thread are released. All Java threads waiting for this thread to die are notified.
    pub fn detachCurrentThread(self: *JavaVM) !void {
        return try checkError(self._cJavaVM.?.*.*.DetachCurrentThread.?(self._cJavaVM));
    }

    /// Returns the environment for the current thread, if it is attached to a Java VM.
    pub fn getEnv(self: *JavaVM, penv: *JNIEnv, version: jint) !void {
        return try checkError(self._cJavaVM.?.*.*.GetEnv.?(self._cJavaVM, @ptrCast(penv), version));
    }

    /// Same semantics as AttachCurrentThread, but the newly-created java.lang.Thread instance is a daemon.
    pub fn attachCurrentThreadAsDaemon(self: *JavaVM, penv: *JNIEnv, args: ?*anyopaque) !void {
        return try checkError(self._cJavaVM.?.*.*.AttachCurrentThreadAsDaemon.?(self._cJavaVM, @ptrCast(penv), args));
    }
};

/// JNIENv wrapper.
pub const JNIEnv = struct {
    // Raw cjni JNIEnv.
    _cJNIEnv: *cjni.JNIEnv,

    /// Converts a raw cjni JNIEnv to a JNIEnv.
    pub inline fn warp(env: *cjni.JNIEnv) JNIEnv {
        return JNIEnv{ ._cJNIEnv = env };
    }

    /// Returns the version of the native method interface.
    pub inline fn getVersion(self: *const JNIEnv) JNIVersion {
        return switch (self._cJNIEnv.*.*.GetVersion.?(self._cJNIEnv)) {
            cjni.JNI_VERSION_1_1 => JNIVersion.JNI1_1,
            cjni.JNI_VERSION_1_2 => JNIVersion.JNI1_2,
            cjni.JNI_VERSION_1_4 => JNIVersion.JNI1_4,
            cjni.JNI_VERSION_1_6 => JNIVersion.JNI1_6,
            cjni.JNI_VERSION_1_8 => JNIVersion.JNI1_8,
            cjni.JNI_VERSION_9 => JNIVersion.JNI9,
            cjni.JNI_VERSION_10 => JNIVersion.JNI10,
            cjni.JNI_VERSION_19 => JNIVersion.JNI19,
            cjni.JNI_VERSION_20 => JNIVersion.JNI20,
            cjni.JNI_VERSION_21 => JNIVersion.JNI21,
            else => JNIVersion.JNIInvalidVersion,
        };
    }

    /// Loads a class from a buffer of raw class data.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#defineclass
    pub inline fn defineClass(self: *const JNIEnv, className: [*:0]const u8, loader: jobject, buf: [*]const jbyte, len: jsize) jclass {
        return self._cJNIEnv.*.*.DefineClass.?(self._cJNIEnv, className, loader, buf, len);
    }

    /// Finds a class from the fully-qualified name of the class.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#findclass
    pub inline fn findClass(self: *const JNIEnv, name: [*:0]const u8) jclass {
        return self._cJNIEnv.*.*.FindClass.?(self._cJNIEnv, name);
    }

    /// Converts a `java.lang.reflect.Method` or `java.lang.reflect.Constructor` object to a method ID.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#fromreflectedmethod
    pub inline fn fromReflectedMethod(self: *const JNIEnv, method: jobject) jmethodID {
        return self._cJNIEnv.*.*.FromReflectedMethod.?(self._cJNIEnv, method);
    }

    /// Converts a `java.lang.reflect.Field` to a field ID.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#fromreflectedfield
    pub inline fn fromReflectedField(self: *const JNIEnv, field: jobject) jfieldID {
        return self._cJNIEnv.*.*.FromReflectedField.?(self._cJNIEnv, field);
    }

    /// Converts a method ID derived from `cls` to a `java.lang.reflect.Method` or `java.lang.reflect.Constructor` object.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#toreflectedmethod
    pub inline fn toReflectedMethod(self: *const JNIEnv, cls: jclass, methodID: jmethodID, isStatic: bool) jobject {
        return self._cJNIEnv.*.*.ToReflectedMethod.?(self._cJNIEnv, cls, methodID, boolToJboolean(isStatic));
    }

    /// Returns the object that represents the superclass of the class specified by `sub`.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getsuperclass
    pub inline fn getSuperclass(self: *const JNIEnv, sub: jclass) jclass {
        return self._cJNIEnv.*.*.GetSuperclass.?(self._cJNIEnv, sub);
    }

    /// Determines whether an object of `sub` can be safely `sup` to clazz2.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#isassignablefrom
    pub inline fn isAssignableFrom(self: *const JNIEnv, sub: jclass, sup: jclass) bool {
        return jbooleanToBool(self._cJNIEnv.*.*.IsAssignableFrom.?(self._cJNIEnv, sub, sup));
    }

    /// Converts a field ID derived from `cls` to a `java.lang.reflect.Field` object.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#toreflectedfield
    pub inline fn toReflectedField(self: *const JNIEnv, cls: jclass, fieldID: jfieldID, isStatic: bool) jobject {
        return self._cJNIEnv.*.*.ToReflectedField.?(self._cJNIEnv, cls, fieldID, boolToJboolean(isStatic));
    }

    /// Causes a `java.lang.Throwable` object to be thrown.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#throw
    pub inline fn throw(self: *const JNIEnv, obj: jthrowable) !void {
        return try checkError(self._cJNIEnv.*.*.Throw.?(self._cJNIEnv, obj));
    }

    /// Constructs an exception object from the specified class with the message specified by message
    /// and causes that exception to be thrown.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#thrownew
    pub inline fn throwNew(self: *const JNIEnv, clazz: jclass, msg: [*:0]const u8) !void {
        return try checkError(self._cJNIEnv.*.*.ThrowNew.?(self._cJNIEnv, clazz, msg));
    }

    /// Determines if an exception is being thrown. The exception stays being thrown until either the
    /// native code calls ExceptionClear(), or the Java code handles the exception.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#exceptionoccurred
    pub inline fn exceptionOccurred(self: *const JNIEnv) jthrowable {
        return self._cJNIEnv.*.*.ExceptionOccurred.?(self._cJNIEnv);
    }

    /// Prints an exception and a backtrace of the stack to a system error-reporting channel.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#exceptiondescribe
    pub inline fn exceptionDescribe(self: *const JNIEnv) void {
        return self._cJNIEnv.*.*.ExceptionDescribe.?(self._cJNIEnv);
    }

    /// Clears any exception that is currently being thrown. If no exception is currently being thrown,
    /// this routine has no effect.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#exceptionclear
    pub inline fn exceptionClear(self: *const JNIEnv) void {
        return self._cJNIEnv.*.*.ExceptionClear.?(self._cJNIEnv);
    }

    /// Raises a fatal error and does not expect the VM to recover. This function does not return.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#fatalerror
    pub inline fn fatalError(self: *const JNIEnv, msg: [*:0]const u8) void {
        return self._cJNIEnv.*.*.FatalError.?(self._cJNIEnv, msg);
    }

    /// Creates a new local reference frame, in which at least a given number of local references can be created.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#pushlocalframe
    pub inline fn pushLocalFrame(self: *const JNIEnv, capacity: jint) !void {
        return try checkError(self._cJNIEnv.*.*.PushLocalFrame.?(self._cJNIEnv, capacity));
    }

    /// Pops off the current local reference frame, frees all the local references, and returns a
    /// local reference in the previous local reference frame for the given result object.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#poplocalframe
    pub inline fn popLocalFrame(self: *const JNIEnv, result: jobject) jobject {
        return self._cJNIEnv.*.*.PopLocalFrame.?(self._cJNIEnv, result);
    }

    /// Creates a new global reference to the object referred to by the obj argument. The obj argument
    /// may be a global or local reference.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#newglobalref
    pub inline fn newGlobalRef(self: *const JNIEnv, lobj: jobject) jobject {
        return self._cJNIEnv.*.*.NewGlobalRef.?(self._cJNIEnv, lobj);
    }

    /// Deletes the global reference pointed to by globalRef.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#deleteglobalref
    pub inline fn deleteGlobalRef(self: *const JNIEnv, gref: jobject) void {
        return self._cJNIEnv.*.*.DeleteGlobalRef.?(self._cJNIEnv, gref);
    }

    /// Deletes the local reference pointed to by localRef.
    ///
    /// See:https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#deletelocalref
    pub inline fn deleteLocalRef(self: *const JNIEnv, obj: jobject) void {
        return self._cJNIEnv.*.*.DeleteLocalRef.?(self._cJNIEnv, obj);
    }

    /// Tests whether two references refer to the same Java object.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#issameobject
    pub inline fn isSameObject(self: *const JNIEnv, obj1: jobject, obj2: jobject) bool {
        return jbooleanToBool(self._cJNIEnv.*.*.IsSameObject.?(self._cJNIEnv, obj1, obj2));
    }

    /// Creates a new local reference that refers to the same object as ref. The given ref may be a
    /// global or local reference.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#newlocalref
    pub inline fn newLocalRef(self: *const JNIEnv, ref: jobject) jobject {
        return self._cJNIEnv.*.*.NewLocalRef.?(self._cJNIEnv, ref);
    }

    /// Ensures that at least a given number of local references can be created in the current thread.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#ensurelocalcapacity
    pub inline fn ensureLocalCapacity(self: *const JNIEnv, capacity: jint) !void {
        return try checkError(self._cJNIEnv.*.*.EnsureLocalCapacity.?(self._cJNIEnv, capacity));
    }

    /// Allocates a new Java object without invoking any of the constructors for the object. Returns
    /// a reference to the object.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#allocobject
    pub inline fn allocObject(self: *const JNIEnv, clazz: jclass) jobject {
        return self._cJNIEnv.*.*.AllocObject.?(self._cJNIEnv, clazz);
    }

    /// Constructs a new Java object. The method ID indicates which constructor method to invoke.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#newobject
    pub inline fn newObject(self: *const JNIEnv, clazz: jclass, methodID: jmethodID, args: [*]const jvalue) jobject {
        return self._cJNIEnv.*.*.NewObjectA.?(self._cJNIEnv, clazz, methodID, args);
    }

    /// Returns the class of an object.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getobjectclass
    pub inline fn getObjectClass(self: *const JNIEnv, obj: jobject) jclass {
        return self._cJNIEnv.*.*.GetObjectClass.?(self._cJNIEnv, obj);
    }

    /// Tests whether an object is an instance of a class.
    ///
    /// See:https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#isinstanceof
    pub inline fn isInstanceOf(self: *const JNIEnv, obj: jobject, clazz: jclass) bool {
        return jbooleanToBool(self._cJNIEnv.*.*.IsInstanceOf.?(self._cJNIEnv, obj, clazz));
    }

    /// Returns the method ID for an instance (nonstatic) method of a class or interface.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getmethodid
    pub inline fn getMethodID(self: *const JNIEnv, clazz: jclass, name: [*:0]const u8, sig: [*:0]const u8) jmethodID {
        return self._cJNIEnv.*.*.GetMethodID.?(self._cJNIEnv, clazz, name, sig);
    }

    /// Calls a class method (nonstatic) on an object instance.
    pub inline fn callMethod(self: *const JNIEnv, obj: jobject, comptime ReturnType: type, methodID: jmethodID, args: [*]const jvalue) ReturnType {
        return switch (ReturnType) {
            jobject => self._cJNIEnv.*.*.CallObjectMethodA.?(self._cJNIEnv, obj, methodID, args),
            jboolean => self._cJNIEnv.*.*.CallBooleanMethodA.?(self._cJNIEnv, obj, methodID, args),
            bool => jbooleanToBool(self._cJNIEnv.*.*.CallBooleanMethodA.?(self._cJNIEnv, obj, methodID, args)),
            jbyte => self._cJNIEnv.*.*.CallByteMethodA.?(self._cJNIEnv, obj, methodID, args),
            jchar => self._cJNIEnv.*.*.CallCharMethodA.?(self._cJNIEnv, obj, methodID, args),
            jshort => self._cJNIEnv.*.*.CallShortMethodA.?(self._cJNIEnv, obj, methodID, args),
            jint => self._cJNIEnv.*.*.CallIntMethodA.?(self._cJNIEnv, obj, methodID, args),
            jlong => self._cJNIEnv.*.*.CallLongMethodA.?(self._cJNIEnv, obj, methodID, args),
            jfloat => self._cJNIEnv.*.*.CallFloatMethodA.?(self._cJNIEnv, obj, methodID, args),
            jdouble => self._cJNIEnv.*.*.CallDoubleMethodA.?(self._cJNIEnv, obj, methodID, args),
            void => self._cJNIEnv.*.*.CallVoidMethodA.?(self._cJNIEnv, obj, methodID, args),
            else => @compileError("Unsupported return type"),
        };
    }

    /// Calls a class method (nonstatic) on an object instance via it's name and signature.
    pub inline fn callMethodByName(self: *const JNIEnv, obj: jobject, comptime ReturnType: type, method_name: [*:0]const u8, method_sig: [*:0]const u8, args: [*]const jvalue) ReturnType {
        const clazz = self.getObjectClass(obj);
        const methodID = self.getMethodID(clazz, method_name, method_sig);

        return self.callMethod(obj, ReturnType, methodID, args);
    }

    /// Calls a class method (nonstatic) on an object instance without adhering to polymorphism.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#callnonvirtualtypemethod-routines-callnonvirtualtypemethoda-routines-callnonvirtualtypemethodv-routines
    pub inline fn callNonvirtualMethod(self: *const JNIEnv, obj: jobject, clazz: jclass, comptime ReturnType: type, methodID: jmethodID, args: [*]const jvalue) ReturnType {
        return switch (ReturnType) {
            jobject => self._cJNIEnv.*.*.CallNonvirtualObjectMethodA.?(self._cJNIEnv, obj, clazz, methodID, args),
            jboolean => self._cJNIEnv.*.*.CallNonvirtualBooleanMethodA.?(self._cJNIEnv, obj, clazz, methodID, args),
            bool => jbooleanToBool(self._cJNIEnv.*.*.CallNonvirtualBooleanMethodA.?(self._cJNIEnv, obj, clazz, methodID, args)),
            jbyte => self._cJNIEnv.*.*.CallNonvirtualByteMethodA.?(self._cJNIEnv, obj, clazz, methodID, args),
            jchar => self._cJNIEnv.*.*.CallNonvirtualCharMethodA.?(self._cJNIEnv, obj, clazz, methodID, args),
            jshort => self._cJNIEnv.*.*.CallNonvirtualShortMethodA.?(self._cJNIEnv, obj, clazz, methodID, args),
            jint => self._cJNIEnv.*.*.CallNonvirtualIntMethodA.?(self._cJNIEnv, obj, clazz, methodID, args),
            jlong => self._cJNIEnv.*.*.CallNonvirtualLongMethodA.?(self._cJNIEnv, obj, clazz, methodID, args),
            jfloat => self._cJNIEnv.*.*.CallNonvirtualFloatMethodA.?(self._cJNIEnv, obj, clazz, methodID, args),
            jdouble => self._cJNIEnv.*.*.CallNonvirtualDoubleMethodA.?(self._cJNIEnv, obj, clazz, methodID, args),
            void => self._cJNIEnv.*.*.CallNonvirtualVoidMethodA.?(self._cJNIEnv, obj, clazz, methodID, args),
            else => @compileError("Unsupported return type"),
        };
    }

    /// Returns the field ID for an instance (nonstatic) field of a class.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getfieldid
    pub inline fn getFieldID(self: *const JNIEnv, clazz: jclass, name: [*:0]const u8, sig: [*:0]const u8) jfieldID {
        return self._cJNIEnv.*.*.GetFieldID.?(self._cJNIEnv, clazz, name, sig);
    }

    /// Gets a class field (nonstatic) on an object instance.
    pub inline fn getField(self: *const JNIEnv, obj: jobject, comptime ReturnType: type, fieldID: jfieldID) ReturnType {
        return switch (ReturnType) {
            jobject => self._cJNIEnv.*.*.GetObjectField.?(self._cJNIEnv, obj, fieldID),
            jboolean => self._cJNIEnv.*.*.GetBooleanField.?(self._cJNIEnv, obj, fieldID),
            bool => jbooleanToBool(self._cJNIEnv.*.*.GetBooleanField.?(self._cJNIEnv, obj, fieldID)),
            jbyte => self._cJNIEnv.*.*.GetByteField.?(self._cJNIEnv, obj, fieldID),
            jchar => self._cJNIEnv.*.*.GetCharField.?(self._cJNIEnv, obj, fieldID),
            jshort => self._cJNIEnv.*.*.GetShortField.?(self._cJNIEnv, obj, fieldID),
            jint => self._cJNIEnv.*.*.GetIntField.?(self._cJNIEnv, obj, fieldID),
            jlong => self._cJNIEnv.*.*.GetLongField.?(self._cJNIEnv, obj, fieldID),
            jfloat => self._cJNIEnv.*.*.GetFloatField.?(self._cJNIEnv, obj, fieldID),
            jdouble => self._cJNIEnv.*.*.GetDoubleField.?(self._cJNIEnv, obj, fieldID),
            else => @compileError("Unsupported return type"),
        };
    }

    /// Gets a class field (nonstatic) on an object instance via it's name and signature.
    pub inline fn getFieldByName(self: *const JNIEnv, obj: jobject, comptime ReturnType: type, field_name: [*:0]const u8, field_sig: [*:0]const u8) ReturnType {
        const clazz = self.getObjectClass(obj);
        const fieldID = self.getFieldID(clazz, field_name, field_sig);

        return self.getField(obj, ReturnType, fieldID);
    }

    /// Sets a class field (nonstatic) on an object instance.
    pub inline fn setField(self: *const JNIEnv, obj: jobject, comptime ValueType: type, fieldID: jfieldID, val: ValueType) void {
        return switch (ValueType) {
            jobject => self._cJNIEnv.*.*.SetObjectField.?(self._cJNIEnv, obj, fieldID, val),
            jboolean => self._cJNIEnv.*.*.SetBooleanField.?(self._cJNIEnv, obj, fieldID, val),
            bool => self._cJNIEnv.*.*.SetBooleanField.?(self._cJNIEnv, obj, fieldID, boolToJboolean(val)),
            jbyte => self._cJNIEnv.*.*.SetByteField.?(self._cJNIEnv, obj, fieldID, val),
            jchar => self._cJNIEnv.*.*.SetCharField.?(self._cJNIEnv, obj, fieldID, val),
            jshort => self._cJNIEnv.*.*.SetShortField.?(self._cJNIEnv, obj, fieldID, val),
            jint => self._cJNIEnv.*.*.SetIntField.?(self._cJNIEnv, obj, fieldID, val),
            jlong => self._cJNIEnv.*.*.SetLongField.?(self._cJNIEnv, obj, fieldID, val),
            jfloat => self._cJNIEnv.*.*.SetFloatField.?(self._cJNIEnv, obj, fieldID, val),
            jdouble => self._cJNIEnv.*.*.SetDoubleField.?(self._cJNIEnv, obj, fieldID, val),
            else => @compileError("Unsupported return type"),
        };
    }

    /// Sets a class field (nonstatic) on an object instance via it's name and signature.
    pub inline fn setFieldByName(self: *const JNIEnv, obj: jobject, comptime ValueType: type, field_name: [*:0]const u8, field_sig: [*:0]const u8, val: ValueType) void {
        const clazz = self.getObjectClass(obj);
        const fieldID = self.getFieldID(clazz, field_name, field_sig);

        return self.setField(obj, ValueType, fieldID, val);
    }

    /// Returns the method ID for a static method of a class.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getstaticmethodid
    pub inline fn getStaticMethodID(self: *const JNIEnv, clazz: jclass, name: [*:0]const u8, sig: [*:0]const u8) jmethodID {
        return self._cJNIEnv.*.*.GetStaticMethodID.?(self._cJNIEnv, clazz, name, sig);
    }

    /// Calls a static method of a class.
    pub inline fn callStaticMethod(self: *const JNIEnv, clazz: jclass, comptime ReturnType: type, methodID: jmethodID, args: [*]const jvalue) ReturnType {
        return switch (ReturnType) {
            jobject => self._cJNIEnv.*.*.CallStaticObjectMethodA.?(self._cJNIEnv, clazz, methodID, args),
            jboolean => self._cJNIEnv.*.*.CallStaticBooleanMethodA.?(self._cJNIEnv, clazz, methodID, args),
            bool => jbooleanToBool(self._cJNIEnv.*.*.CallStaticBooleanMethodA.?(self._cJNIEnv, clazz, methodID, args)),
            jbyte => self._cJNIEnv.*.*.CallStaticByteMethodA.?(self._cJNIEnv, clazz, methodID, args),
            jchar => self._cJNIEnv.*.*.CallStaticCharMethodA.?(self._cJNIEnv, clazz, methodID, args),
            jshort => self._cJNIEnv.*.*.CallStaticShortMethodA.?(self._cJNIEnv, clazz, methodID, args),
            jint => self._cJNIEnv.*.*.CallStaticIntMethodA.?(self._cJNIEnv, clazz, methodID, args),
            jlong => self._cJNIEnv.*.*.CallStaticLongMethodA.?(self._cJNIEnv, clazz, methodID, args),
            jfloat => self._cJNIEnv.*.*.CallStaticFloatMethodA.?(self._cJNIEnv, clazz, methodID, args),
            jdouble => self._cJNIEnv.*.*.CallStaticDoubleMethodA.?(self._cJNIEnv, clazz, methodID, args),
            void => self._cJNIEnv.*.*.CallStaticVoidMethodA.?(self._cJNIEnv, clazz, methodID, args),
            else => @compileError("Unsupported return type"),
        };
    }

    /// Returns the field ID for a static field of a class.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getstaticfieldid
    pub inline fn getStaticFieldID(self: *const JNIEnv, clazz: jclass, name: [*:0]const u8, sig: [*:0]const u8) jfieldID {
        return self._cJNIEnv.*.*.GetStaticFieldID.?(self._cJNIEnv, clazz, name, sig);
    }

    /// Gets a static field of a class.
    pub inline fn getStaticField(self: *const JNIEnv, clazz: jclass, comptime ReturnType: type, fieldID: jfieldID) ReturnType {
        return switch (ReturnType) {
            jobject => self._cJNIEnv.*.*.GetStaticObjectField.?(self._cJNIEnv, clazz, fieldID),
            jboolean => self._cJNIEnv.*.*.GetStaticBooleanField.?(self._cJNIEnv, clazz, fieldID),
            bool => jbooleanToBool(self._cJNIEnv.*.*.GetStaticBooleanField.?(self._cJNIEnv, clazz, fieldID)),
            jbyte => self._cJNIEnv.*.*.GetStaticByteField.?(self._cJNIEnv, clazz, fieldID),
            jchar => self._cJNIEnv.*.*.GetStaticCharField.?(self._cJNIEnv, clazz, fieldID),
            jshort => self._cJNIEnv.*.*.GetStaticShortField.?(self._cJNIEnv, clazz, fieldID),
            jint => self._cJNIEnv.*.*.GetStaticIntField.?(self._cJNIEnv, clazz, fieldID),
            jlong => self._cJNIEnv.*.*.GetStaticLongField.?(self._cJNIEnv, clazz, fieldID),
            jfloat => self._cJNIEnv.*.*.GetStaticFloatField.?(self._cJNIEnv, clazz, fieldID),
            jdouble => self._cJNIEnv.*.*.GetStaticDoubleField.?(self._cJNIEnv, clazz, fieldID),
            else => @compileError("Unsupported return type"),
        };
    }

    /// Sets a static field of a class.
    pub inline fn setStaticField(self: *const JNIEnv, clazz: jclass, comptime ReturnType: type, fieldID: jfieldID, val: ReturnType) void {
        return switch (ReturnType) {
            jobject => self._cJNIEnv.*.*.SetStaticObjectField.?(self._cJNIEnv, clazz, fieldID, val),
            jboolean => self._cJNIEnv.*.*.SetStaticBooleanField.?(self._cJNIEnv, clazz, fieldID, val),
            bool => self._cJNIEnv.*.*.SetStaticBooleanField.?(self._cJNIEnv, clazz, fieldID, boolToJboolean(val)),
            jbyte => self._cJNIEnv.*.*.SetStaticByteField.?(self._cJNIEnv, clazz, fieldID, val),
            jchar => self._cJNIEnv.*.*.SetStaticCharField.?(self._cJNIEnv, clazz, fieldID, val),
            jshort => self._cJNIEnv.*.*.SetStaticShortField.?(self._cJNIEnv, clazz, fieldID, val),
            jint => self._cJNIEnv.*.*.SetStaticIntField.?(self._cJNIEnv, clazz, fieldID, val),
            jlong => self._cJNIEnv.*.*.SetStaticLongField.?(self._cJNIEnv, clazz, fieldID, val),
            jfloat => self._cJNIEnv.*.*.SetStaticFloatField.?(self._cJNIEnv, clazz, fieldID, val),
            jdouble => self._cJNIEnv.*.*.SetStaticDoubleField.?(self._cJNIEnv, clazz, fieldID, val),
            else => @compileError("Unsupported return type"),
        };
    }

    /// Constructs a new java.lang.String object from an array of Unicode characters.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#newstring
    pub inline fn newString(self: *const JNIEnv, unicode: [*:0]const jchar, len: jsize) jstring {
        return self._cJNIEnv.*.*.NewString.?(self._cJNIEnv, unicode, len);
    }

    /// Returns the length (the count of Unicode characters) of a Java string.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getstringlength
    pub inline fn getStringLength(self: *const JNIEnv, str: jstring) jsize {
        return self._cJNIEnv.*.*.GetStringLength.?(self._cJNIEnv, str);
    }

    /// Returns a pointer to the array of Unicode characters of the string.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getstringchars
    pub inline fn getStringChars(self: *const JNIEnv, str: jstring, isCopy: *bool) [*:0]const jchar {
        var isCopy_: jboolean = 0;
        const chars = self._cJNIEnv.*.*.GetStringChars.?(self._cJNIEnv, str, &isCopy_);
        isCopy.* = jbooleanToBool(isCopy_);
        return chars;
    }

    /// Informs the VM that the native code no longer needs access to chars.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#releasestringchars
    pub inline fn releaseStringChars(self: *const JNIEnv, str: jstring, chars: [*:0]const jchar) void {
        return self._cJNIEnv.*.*.ReleaseStringChars.?(self._cJNIEnv, str, chars);
    }

    /// Constructs a new java.lang.String object from an array of characters in modified UTF-8 encoding.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#newstringutf
    pub inline fn newStringUTF(self: *const JNIEnv, utf: [*:0]const u8) jstring {
        return self._cJNIEnv.*.*.NewStringUTF.?(self._cJNIEnv, utf);
    }

    /// Returns the length in bytes of the modified UTF-8 representation of a string.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getstringutflength
    pub inline fn getStringUTFLength(self: *const JNIEnv, str: jstring) jsize {
        return self._cJNIEnv.*.*.GetStringUTFLength.?(self._cJNIEnv, str);
    }

    /// Returns a pointer to an array of bytes representing the string in modified UTF-8 encoding.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getstringutfchars
    pub inline fn getStringUTFChars(self: *const JNIEnv, str: jstring, isCopy: *bool) [*:0]const u8 {
        var isCopy_: jboolean = 0;
        const chars = self._cJNIEnv.*.*.GetStringUTFChars.?(self._cJNIEnv, str, &isCopy_);
        isCopy.* = jbooleanToBool(isCopy_);
        return chars;
    }

    /// Informs the VM that the native code no longer needs access to utf.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#releasestringutfchars
    pub inline fn releaseStringUTFChars(self: *const JNIEnv, str: jstring, chars: [*:0]const u8) void {
        return self._cJNIEnv.*.*.ReleaseStringUTFChars.?(self._cJNIEnv, str, chars);
    }

    /// Returns the number of elements in the array.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getarraylength
    pub inline fn getArrayLength(self: *const JNIEnv, array: jarray) jsize {
        return self._cJNIEnv.*.*.GetArrayLength.?(self._cJNIEnv, array);
    }

    /// Returns an array type based on the initial passed type of a single instance.
    fn ElementTypeToArrayType(comptime ElementType: type) type {
        return switch (ElementType) {
            jboolean => jbooleanArray,
            jbyte => jbyteArray,
            jchar => jcharArray,
            jshort => jshortArray,
            jint => jintArray,
            jlong => jlongArray,
            jfloat => jfloatArray,
            jdouble => jdoubleArray,
            jobject => jobjectArray,
            else => @compileError("Unsupported element type"),
        };
    }

    /// Returns a new array of the specified size and element type.
    pub inline fn newPrimitiveArray(self: *const JNIEnv, comptime ElementType: type, len: jsize) ElementTypeToArrayType(ElementType) {
        return switch (ElementType) {
            jboolean => self._cJNIEnv.*.*.NewBooleanArray.?(self._cJNIEnv, len),
            jbyte => self._cJNIEnv.*.*.NewByteArray.?(self._cJNIEnv, len),
            jchar => self._cJNIEnv.*.*.NewCharArray.?(self._cJNIEnv, len),
            jshort => self._cJNIEnv.*.*.NewShortArray.?(self._cJNIEnv, len),
            jint => self._cJNIEnv.*.*.NewIntArray.?(self._cJNIEnv, len),
            jlong => self._cJNIEnv.*.*.NewLongArray.?(self._cJNIEnv, len),
            jfloat => self._cJNIEnv.*.*.NewFloatArray.?(self._cJNIEnv, len),
            jdouble => self._cJNIEnv.*.*.NewDoubleArray.?(self._cJNIEnv, len),
            jobject => @compileError("Use newObjectArray for jobject"),
            else => @compileError("Unsupported element type"),
        };
    }

    /// Constructs a new array holding objects in class elementClass.
    ///
    /// See:https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#newobjectarray
    pub inline fn newObjectArray(self: *const JNIEnv, len: jsize, elementClass: jclass, initialElement: jobject) jobjectArray {
        return self._cJNIEnv.*.*.NewObjectArray.?(self._cJNIEnv, len, elementClass, initialElement);
    }

    /// Returns an element of an Object array.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getobjectarrayelement
    pub inline fn getObjectArrayElement(self: *const JNIEnv, array: jobjectArray, index: jsize) jobject {
        return self._cJNIEnv.*.*.GetObjectArrayElement.?(self._cJNIEnv, array, index);
    }

    /// Sets an element of an Object array.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#setobjectarrayelement
    pub inline fn setObjectArrayElement(self: *const JNIEnv, array: jobjectArray, index: jsize, val: jobject) void {
        return self._cJNIEnv.*.*.SetObjectArrayElement.?(self._cJNIEnv, array, index, val);
    }

    /// Returns a pointer to the elements of a primitive array, and indicating whether the pointer points
    /// to a copy of the original array elements.
    pub inline fn getPrimitiveArrayElements(self: *const JNIEnv, comptime ElementType: type, array: jarray, isCopy: *bool) [*]ElementType {
        var isCopy_: jboolean = 0;

        const elems = switch (ElementType) {
            jboolean => self._cJNIEnv.*.*.GetBooleanArrayElements.?(self._cJNIEnv, array, &isCopy_),
            jbyte => self._cJNIEnv.*.*.GetByteArrayElements.?(self._cJNIEnv, array, &isCopy_),
            jchar => self._cJNIEnv.*.*.GetCharArrayElements.?(self._cJNIEnv, array, &isCopy_),
            jshort => self._cJNIEnv.*.*.GetShortArrayElements.?(self._cJNIEnv, array, &isCopy_),
            jint => self._cJNIEnv.*.*.GetIntArrayElements.?(self._cJNIEnv, array, &isCopy_),
            jlong => self._cJNIEnv.*.*.GetLongArrayElements.?(self._cJNIEnv, array, &isCopy_),
            jfloat => self._cJNIEnv.*.*.GetFloatArrayElements.?(self._cJNIEnv, array, &isCopy_),
            jdouble => self._cJNIEnv.*.*.GetDoubleArrayElements.?(self._cJNIEnv, array, &isCopy_),
            jobject => @compileError("Use getObjectArrayElement for jobject"),
            else => @compileError("Unsupported element type"),
        };

        isCopy.* = jbooleanToBool(isCopy_);

        return elems;
    }

    /// Informs the VM that the native code no longer needs access to elems.
    pub inline fn releasePrimitiveArrayElements(self: *const JNIEnv, comptime ElementType: type, array: jarray, elems: [*]ElementType, mode: jReleasePrimitiveArrayElementsMode) void {
        return switch (ElementType) {
            jboolean => self._cJNIEnv.*.*.ReleaseBooleanArrayElements.?(self._cJNIEnv, array, elems, @intFromEnum(mode)),
            jbyte => self._cJNIEnv.*.*.ReleaseByteArrayElements.?(self._cJNIEnv, array, elems, @intFromEnum(mode)),
            jchar => self._cJNIEnv.*.*.ReleaseCharArrayElements.?(self._cJNIEnv, array, elems, @intFromEnum(mode)),
            jshort => self._cJNIEnv.*.*.ReleaseShortArrayElements.?(self._cJNIEnv, array, elems, @intFromEnum(mode)),
            jint => self._cJNIEnv.*.*.ReleaseIntArrayElements.?(self._cJNIEnv, array, elems, @intFromEnum(mode)),
            jlong => self._cJNIEnv.*.*.ReleaseLongArrayElements.?(self._cJNIEnv, array, elems, @intFromEnum(mode)),
            jfloat => self._cJNIEnv.*.*.ReleaseFloatArrayElements.?(self._cJNIEnv, array, elems, @intFromEnum(mode)),
            jdouble => self._cJNIEnv.*.*.ReleaseDoubleArrayElements.?(self._cJNIEnv, array, elems, @intFromEnum(mode)),
            jobject => @compileError("Use setObjectArrayElement for jobject"),
            else => @compileError("Unsupported element type"),
        };
    }

    /// Copies a region of a primitive array into a buffer.
    pub inline fn getArrayRegion(self: *const JNIEnv, comptime ElementType: type, array: jarray, start: jsize, len: jsize, buf: [*]ElementType) void {
        return switch (ElementType) {
            jboolean => self._cJNIEnv.*.*.GetBooleanArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jbyte => self._cJNIEnv.*.*.GetByteArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jchar => self._cJNIEnv.*.*.GetCharArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jshort => self._cJNIEnv.*.*.GetShortArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jint => self._cJNIEnv.*.*.GetIntArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jlong => self._cJNIEnv.*.*.GetLongArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jfloat => self._cJNIEnv.*.*.GetFloatArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jdouble => self._cJNIEnv.*.*.GetDoubleArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jobject => @compileError("Use getObjectArrayElement for jobject"),
            else => @compileError("Unsupported element type"),
        };
    }

    /// Copies back a region of a primitive array from a buffer.
    pub inline fn setArrayRegion(self: *const JNIEnv, comptime ElementType: type, array: jarray, start: jsize, len: jsize, buf: [*]const ElementType) void {
        return switch (ElementType) {
            jboolean => self._cJNIEnv.*.*.SetBooleanArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jbyte => self._cJNIEnv.*.*.SetByteArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jchar => self._cJNIEnv.*.*.SetCharArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jshort => self._cJNIEnv.*.*.SetShortArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jint => self._cJNIEnv.*.*.SetIntArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jlong => self._cJNIEnv.*.*.SetLongArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jfloat => self._cJNIEnv.*.*.SetFloatArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jdouble => self._cJNIEnv.*.*.SetDoubleArrayRegion.?(self._cJNIEnv, array, start, len, buf),
            jobject => @compileError("Use setObjectArrayElement for jobject"),
            else => @compileError("Unsupported element type"),
        };
    }

    /// Registers native methods with the class specified by the `clazz` argument.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#registernatives
    pub inline fn registerNatives(self: *const JNIEnv, clazz: jclass, methods: [*]const cjni.JNINativeMethod, nMethods: jint) !void {
        return try checkError(self._cJNIEnv.*.*.RegisterNatives.?(self._cJNIEnv, clazz, methods, nMethods));
    }

    /// Unregisters native methods of a class.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#unregisternatives
    pub inline fn unregisterNatives(self: *const JNIEnv, clazz: jclass) !void {
        return try checkError(self._cJNIEnv.*.*.UnregisterNatives.?(self._cJNIEnv, clazz));
    }

    /// Enters the monitor associated with the underlying Java object referred to by `obj`.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#monitorenter
    pub inline fn monitorEnter(self: *const JNIEnv, obj: jobject) !void {
        return try checkError(self._cJNIEnv.*.*.MonitorEnter.?(self._cJNIEnv, obj));
    }

    /// Enters the monitor associated with the underlying Java object referred to by `obj`.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#monitorexit
    pub inline fn monitorExit(self: *const JNIEnv, obj: jobject) !void {
        return try checkError(self._cJNIEnv.*.*.MonitorExit.?(self._cJNIEnv, obj));
    }

    /// Exits the current monitor.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getjavavm
    pub inline fn getJavaVM(self: *const JNIEnv, vm: *JavaVM) !void {
        return try checkError(self._cJNIEnv.*.*.GetJavaVM.?(self._cJNIEnv, &vm._cJavaVM));
    }

    /// Copies `len` number of Unicode characters beginning at offset `start` to the given buffer `buf`.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getstringregion
    pub inline fn getStringRegion(self: *const JNIEnv, str: jstring, start: jsize, len: jsize, buf: [*]u8) void {
        return self._cJNIEnv.*.*.GetStringRegion.?(self._cJNIEnv, str, start, len, buf);
    }

    /// Translates `len` number of Unicode characters beginning at offset `start` into modified UTF-8
    /// encoding and place the result in the given buffer `buf`.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getstringutfregion
    pub inline fn getStringUTFRegion(self: *const JNIEnv, str: jstring, start: jsize, len: jsize, buf: [*]u8) void {
        return self._cJNIEnv.*.*.GetStringUTFRegion.?(self._cJNIEnv, str, start, len, buf);
    }

    /// Similar to GetStringChars, however native code must not issue JNI calls or cause the thread to block.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getstringcritical-releasestringcritical
    pub inline fn getStringCritical(self: *const JNIEnv, str: jstring, isCopy: *bool) [*:0]const jchar {
        var isCopy_: jboolean = 0;
        const chars = self._cJNIEnv.*.*.GetStringCritical.?(self._cJNIEnv, str, &isCopy_);
        isCopy.* = jbooleanToBool(isCopy_);
        return chars;
    }

    /// Similar to ReleaseStringChars, however native code must not issue JNI calls or cause the thread to block.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getstringcritical-releasestringcritical
    pub inline fn releaseStringCritical(self: *const JNIEnv, str: jstring, carray: [*:0]const jchar) void {
        return self._cJNIEnv.*.*.ReleaseStringCritical.?(self._cJNIEnv, str, carray);
    }

    /// Creates a new weak global reference.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#newweakglobalref
    pub inline fn newWeakGlobalRef(self: *const JNIEnv, obj: jobject) jweak {
        return self._cJNIEnv.*.*.NewWeakGlobalRef.?(self._cJNIEnv, obj);
    }

    /// Delete the VM resources needed for the given weak global reference.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#deleteweakglobalref
    pub inline fn deleteWeakGlobalRef(self: *const JNIEnv, obj: jweak) void {
        return self._cJNIEnv.*.*.DeleteWeakGlobalRef.?(self._cJNIEnv, obj);
    }

    /// Checks if there is a pending exception.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#exceptioncheck
    pub inline fn exceptionCheck(self: *const JNIEnv) bool {
        return jbooleanToBool(self._cJNIEnv.*.*.ExceptionCheck.?(self._cJNIEnv));
    }

    /// Allocates and returns a direct `java.nio.ByteBuffer` referring to the block of memory starting
    /// at the memory address `address` and extending `capacity` bytes.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#newdirectbytebuffer
    pub inline fn newDirectByteBuffer(self: *const JNIEnv, address: usize, capacity: jlong) jobject {
        return self._cJNIEnv.*.*.NewDirectByteBuffer.?(self._cJNIEnv, @ptrFromInt(address), capacity);
    }

    /// Fetches and returns the starting address of the memory region referenced by the given direct `java.nio.Buffer`.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getdirectbufferaddress
    pub inline fn getDirectBufferAddress(self: *const JNIEnv, buf: jobject) usize {
        return @intFromPtr(self._cJNIEnv.*.*.GetDirectBufferAddress.?(self._cJNIEnv, buf));
    }

    /// Fetches and returns the capacity of the memory region referenced by the given direct `java.nio.Buffer`.
    /// The capacity is the number of elements that the memory region contains.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getdirectbuffercapacity
    pub inline fn getDirectBufferCapacity(self: *const JNIEnv, buf: jobject) jlong {
        return self._cJNIEnv.*.*.GetDirectBufferCapacity.?(self._cJNIEnv, buf);
    }

    /// Returns the type of the object referred to by the `obj` argument. The argument obj can either
    /// be a local, global or weak global reference.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getobjectreftype
    pub inline fn getObjectRefType(self: *const JNIEnv, obj: jobject) jobjectRefType {
        return @enumFromInt(self._cJNIEnv.*.*.GetObjectRefType.?(self._cJNIEnv, obj));
    }

    /// Returns the java.lang.Module object for the module that the class is a member of.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#getmodule
    pub inline fn getModule(self: *const JNIEnv, clazz: jclass) jobject {
        return self._cJNIEnv.*.*.GetModule.?(self._cJNIEnv, clazz);
    }

    /// Tests whether an object is a virtual Thread.
    ///
    /// See: https://docs.oracle.com/en/java/javase/22/docs/specs/jni/functions.html#isvirtualthread
    pub inline fn isVirtualThread(self: *const JNIEnv, obj: jobject) bool {
        return jbooleanToBool(self._cJNIEnv.*.*.IsVirtualThread.?(self._cJNIEnv, obj));
    }
};
