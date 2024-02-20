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
/// Used at releasePrimitiveArrayElements
pub const jReleasePrimitiveArrayElementsMode = enum(jint) {
    /// For raw-data, release the reference and allow the GC to free the java array
    /// For buffer-copy, copy back the content and free the buffer
    JNIDefault,
    /// For raw-data, do nothing (the reference is still alive)
    /// For buffer-copy, copy back the content but do not free the buffer (You can use it multiple times)
    JNICommit,
    /// For raw-data, release the reference and allow the GC to free the java array
    /// For buffer-copy, free the buffer but do not copy back the content
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

pub inline fn jboolean2bool(b: jboolean) bool {
    return b != 0;
}

pub inline fn bool2jboolean(b: bool) jboolean {
    return if (b) 1 else 0;
}

pub fn exportJNI(comptime class_name: []const u8, comptime func_struct: type) void {
    inline for (@typeInfo(func_struct).Struct.decls) |decl| {
        const func = comptime @field(func_struct, decl.name);
        const func_type = @TypeOf(func);
        // If it is not a function, skip
        if (!std.mem.startsWith(u8, @typeName(@TypeOf(func)), "fn")) {
            continue;
        }
        // If it is not a function with calling convention .C, skip
        if (@typeInfo(func_type).Fn.calling_convention != .C) {
            continue;
        }
        const tmp_name: []const u8 = comptime ("Java." ++ class_name ++ "." ++ decl.name);
        var export_name: [tmp_name.len]u8 = undefined;
        @setEvalBranchQuota(30000);
        _ = comptime std.mem.replace(u8, tmp_name, ".", "_", export_name[0..]);
        @export(func, .{
            .name = export_name[0..],
            .linkage = .Strong,
        });
    }
}

inline fn valueLen(comptime ArgsType: type) comptime_int {
    const args_type_info = @typeInfo(ArgsType);
    return switch (args_type_info) {
        .Struct => args_type_info.Struct.fields.len,
        .Void => 0,
        else => 1,
    };
}

pub fn toJValues(args: anytype) [valueLen(@TypeOf(args))]jvalue {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);
    if (args_type_info != .Struct) {
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
            bool => [1]jvalue{.{ .z = bool2jboolean(args) }},
            else => @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType)),
        };
    }
    const fields = args_type_info.Struct.fields;
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
            bool => .{ .z = bool2jboolean(value) },
            else => @panic("jvalue type not supported"),
        };
    }
    return output;
}

pub const JavaVM = struct {
    _cJavaVM: ?*cjni.JavaVM = null,

    pub fn destroy(self: *JavaVM) !void {
        return try checkError(self._cJavaVM.?.*.*.DestroyJavaVM.?(self._cJavaVM));
    }

    /// Attach the current thread to the VM and get the JNIEnv. Example:
    /// ```zig
    /// var cEnv: ?*jni.cEnv = null;
    /// jni_util.java_vm.attachCurrentThread(&cEnv, null) catch return;
    /// defer jni_util.java_vm.detachCurrentThread() catch jni_util.warn(cEnv.?, "Dawn", "JNI failed to detach from current thread");
    /// const env = jni.JNIEnv.warp(cEnv.?);
    /// ```
    pub fn attachCurrentThread(self: *JavaVM, penv: *?*cEnv, args: ?*anyopaque) !void {
        return try checkError(self._cJavaVM.?.*.*.AttachCurrentThread.?(self._cJavaVM, @ptrCast(penv), args));
    }

    pub fn detachCurrentThread(self: *JavaVM) !void {
        return try checkError(self._cJavaVM.?.*.*.DetachCurrentThread.?(self._cJavaVM));
    }

    pub fn getEnv(self: *JavaVM, penv: *JNIEnv, version: jint) !void {
        return try checkError(self._cJavaVM.?.*.*.GetEnv.?(self._cJavaVM, &(penv._cJNIEnv), version));
    }

    pub fn attachCurrentThreadAsDaemon(self: *JavaVM, penv: *JNIEnv, args: ?*anyopaque) !void {
        return try checkError(self._cJavaVM.?.*.*.AttachCurrentThreadAsDaemon.?(self._cJavaVM, penv._cJNIEnv, args));
    }
};

pub const JNIEnv = struct {
    _cJNIEnv: *cjni.JNIEnv,

    pub inline fn warp(env: *cjni.JNIEnv) JNIEnv {
        return JNIEnv{ ._cJNIEnv = env };
    }

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

    pub inline fn defineClass(self: *const JNIEnv, className: [*:0]const u8, loader: jobject, buf: [*]const jbyte, len: jsize) jclass {
        return self._cJNIEnv.*.*.DefineClass.?(self._cJNIEnv, className, loader, buf, len);
    }

    pub inline fn findClass(self: *const JNIEnv, name: [*:0]const u8) jclass {
        return self._cJNIEnv.*.*.FindClass.?(self._cJNIEnv, name);
    }

    pub inline fn fromReflectedMethod(self: *const JNIEnv, method: jobject) jmethodID {
        return self._cJNIEnv.*.*.FromReflectedMethod.?(self._cJNIEnv, method);
    }

    pub inline fn fromReflectedField(self: *const JNIEnv, field: jobject) jfieldID {
        return self._cJNIEnv.*.*.FromReflectedField.?(self._cJNIEnv, field);
    }

    pub inline fn toReflectedMethod(self: *const JNIEnv, cls: jclass, methodID: jmethodID, isStatic: bool) jobject {
        return self._cJNIEnv.*.*.ToReflectedMethod.?(self._cJNIEnv, cls, methodID, bool2jboolean(isStatic));
    }

    pub inline fn getSuperclass(self: *const JNIEnv, sub: jclass) jclass {
        return self._cJNIEnv.*.*.GetSuperclass.?(self._cJNIEnv, sub);
    }

    pub inline fn isAssignableFrom(self: *const JNIEnv, sub: jclass, sup: jclass) bool {
        return jboolean2bool(self._cJNIEnv.*.*.IsAssignableFrom.?(self._cJNIEnv, sub, sup));
    }

    pub inline fn toReflectedField(self: *const JNIEnv, cls: jclass, fieldID: jfieldID, isStatic: bool) jobject {
        return self._cJNIEnv.*.*.ToReflectedField.?(self._cJNIEnv, cls, fieldID, bool2jboolean(isStatic));
    }

    pub inline fn throw(self: *const JNIEnv, obj: jthrowable) !void {
        return try checkError(self._cJNIEnv.*.*.Throw.?(self._cJNIEnv, obj));
    }

    pub inline fn throwNew(self: *const JNIEnv, clazz: jclass, msg: [*:0]const u8) !void {
        return try checkError(self._cJNIEnv.*.*.ThrowNew.?(self._cJNIEnv, clazz, msg));
    }

    pub inline fn exceptionOccurred(self: *const JNIEnv) jthrowable {
        return self._cJNIEnv.*.*.ExceptionOccurred.?(self._cJNIEnv);
    }

    pub inline fn exceptionDescribe(self: *const JNIEnv) void {
        return self._cJNIEnv.*.*.ExceptionDescribe.?(self._cJNIEnv);
    }

    pub inline fn exceptionClear(self: *const JNIEnv) void {
        return self._cJNIEnv.*.*.ExceptionClear.?(self._cJNIEnv);
    }

    pub inline fn fatalError(self: *const JNIEnv, msg: [*:0]const u8) void {
        return self._cJNIEnv.*.*.FatalError.?(self._cJNIEnv, msg);
    }

    pub inline fn pushLocalFrame(self: *const JNIEnv, capacity: jint) !void {
        return try checkError(self._cJNIEnv.*.*.PushLocalFrame.?(self._cJNIEnv, capacity));
    }

    pub inline fn popLocalFrame(self: *const JNIEnv, result: jobject) jobject {
        return self._cJNIEnv.*.*.PopLocalFrame.?(self._cJNIEnv, result);
    }

    pub inline fn newGlobalRef(self: *const JNIEnv, lobj: jobject) jobject {
        return self._cJNIEnv.*.*.NewGlobalRef.?(self._cJNIEnv, lobj);
    }

    pub inline fn deleteGlobalRef(self: *const JNIEnv, gref: jobject) void {
        return self._cJNIEnv.*.*.DeleteGlobalRef.?(self._cJNIEnv, gref);
    }

    pub inline fn deleteLocalRef(self: *const JNIEnv, obj: jobject) void {
        return self._cJNIEnv.*.*.DeleteLocalRef.?(self._cJNIEnv, obj);
    }

    pub inline fn isSameObject(self: *const JNIEnv, obj1: jobject, obj2: jobject) bool {
        return jboolean2bool(self._cJNIEnv.*.*.IsSameObject.?(self._cJNIEnv, obj1, obj2));
    }

    pub inline fn newLocalRef(self: *const JNIEnv, ref: jobject) jobject {
        return self._cJNIEnv.*.*.NewLocalRef.?(self._cJNIEnv, ref);
    }

    pub inline fn ensureLocalCapacity(self: *const JNIEnv, capacity: jint) !void {
        return try checkError(self._cJNIEnv.*.*.EnsureLocalCapacity.?(self._cJNIEnv, capacity));
    }

    pub inline fn allocObject(self: *const JNIEnv, clazz: jclass) jobject {
        return self._cJNIEnv.*.*.AllocObject.?(self._cJNIEnv, clazz);
    }

    pub inline fn newObject(self: *const JNIEnv, clazz: jclass, methodID: jmethodID, args: [*]const jvalue) jobject {
        return self._cJNIEnv.*.*.NewObjectA.?(self._cJNIEnv, clazz, methodID, args);
    }

    pub inline fn getObjectClass(self: *const JNIEnv, obj: jobject) jclass {
        return self._cJNIEnv.*.*.GetObjectClass.?(self._cJNIEnv, obj);
    }

    pub inline fn isInstanceOf(self: *const JNIEnv, obj: jobject, clazz: jclass) bool {
        return jboolean2bool(self._cJNIEnv.*.*.IsInstanceOf.?(self._cJNIEnv, obj, clazz));
    }

    pub inline fn getMethodID(self: *const JNIEnv, clazz: jclass, name: [*:0]const u8, sig: [*:0]const u8) jmethodID {
        return self._cJNIEnv.*.*.GetMethodID.?(self._cJNIEnv, clazz, name, sig);
    }

    pub inline fn callMethod(self: *const JNIEnv, obj: jobject, comptime ReturnType: type, methodID: jmethodID, args: [*]const jvalue) ReturnType {
        return switch (ReturnType) {
            jobject => self._cJNIEnv.*.*.CallObjectMethodA.?(self._cJNIEnv, obj, methodID, args),
            jboolean => self._cJNIEnv.*.*.CallBooleanMethodA.?(self._cJNIEnv, obj, methodID, args),
            bool => jboolean2bool(self._cJNIEnv.*.*.CallBooleanMethodA.?(self._cJNIEnv, obj, methodID, args)),
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

    pub inline fn callMethodByName(self: *const JNIEnv, obj: jobject, comptime ReturnType: type, method_name: [*:0]const u8, method_sig: [*:0]const u8, args: [*]const jvalue) ReturnType {
        const clazz = self.getObjectClass(obj);
        const methodID = self.getMethodID(clazz, method_name, method_sig);
        return self.callMethod(obj, ReturnType, methodID, args);
    }

    pub inline fn callNonvirtualMethod(self: *const JNIEnv, obj: jobject, clazz: jclass, comptime ReturnType: type, methodID: jmethodID, args: [*]const jvalue) ReturnType {
        return switch (ReturnType) {
            jobject => self._cJNIEnv.*.*.CallNonvirtualObjectMethodA.?(self._cJNIEnv, obj, clazz, methodID, args),
            jboolean => self._cJNIEnv.*.*.CallNonvirtualBooleanMethodA.?(self._cJNIEnv, obj, clazz, methodID, args),
            bool => jboolean2bool(self._cJNIEnv.*.*.CallNonvirtualBooleanMethodA.?(self._cJNIEnv, obj, clazz, methodID, args)),
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

    pub inline fn getFieldID(self: *const JNIEnv, clazz: jclass, name: [*:0]const u8, sig: [*:0]const u8) jfieldID {
        return self._cJNIEnv.*.*.GetFieldID.?(self._cJNIEnv, clazz, name, sig);
    }

    pub inline fn getField(self: *const JNIEnv, obj: jobject, comptime ReturnType: type, fieldID: jfieldID) ReturnType {
        return switch (ReturnType) {
            jobject => self._cJNIEnv.*.*.GetObjectField.?(self._cJNIEnv, obj, fieldID),
            jboolean => self._cJNIEnv.*.*.GetBooleanField.?(self._cJNIEnv, obj, fieldID),
            bool => jboolean2bool(self._cJNIEnv.*.*.GetBooleanField.?(self._cJNIEnv, obj, fieldID)),
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

    pub inline fn getFieldByName(self: *const JNIEnv, obj: jobject, comptime ReturnType: type, field_name: [*:0]const u8, field_sig: [*:0]const u8) ReturnType {
        const clazz = self.getObjectClass(obj);
        const fieldID = self.getFieldID(clazz, field_name, field_sig);
        return self.getField(obj, ReturnType, fieldID);
    }

    pub inline fn setField(self: *const JNIEnv, obj: jobject, comptime ValueType: type, fieldID: jfieldID, val: ValueType) void {
        return switch (ValueType) {
            jobject => self._cJNIEnv.*.*.SetObjectField.?(self._cJNIEnv, obj, fieldID, val),
            jboolean => self._cJNIEnv.*.*.SetBooleanField.?(self._cJNIEnv, obj, fieldID, val),
            bool => self._cJNIEnv.*.*.SetBooleanField.?(self._cJNIEnv, obj, fieldID, bool2jboolean(val)),
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

    pub inline fn setFieldByName(self: *const JNIEnv, obj: jobject, comptime ValueType: type, field_name: [*:0]const u8, field_sig: [*:0]const u8, val: ValueType) void {
        const clazz = self.getObjectClass(obj);
        const fieldID = self.getFieldID(clazz, field_name, field_sig);
        return self.setField(obj, ValueType, fieldID, val);
    }

    pub inline fn getStaticMethodID(self: *const JNIEnv, clazz: jclass, name: [*:0]const u8, sig: [*:0]const u8) jmethodID {
        return self._cJNIEnv.*.*.GetStaticMethodID.?(self._cJNIEnv, clazz, name, sig);
    }

    pub inline fn callStaticMethod(self: *const JNIEnv, clazz: jclass, comptime ReturnType: type, methodID: jmethodID, args: [*]const jvalue) ReturnType {
        return switch (ReturnType) {
            jobject => self._cJNIEnv.*.*.CallStaticObjectMethodA.?(self._cJNIEnv, clazz, methodID, args),
            jboolean => self._cJNIEnv.*.*.CallStaticBooleanMethodA.?(self._cJNIEnv, clazz, methodID, args),
            bool => jboolean2bool(self._cJNIEnv.*.*.CallStaticBooleanMethodA.?(self._cJNIEnv, clazz, methodID, args)),
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

    pub inline fn getStaticFieldID(self: *const JNIEnv, clazz: jclass, name: [*:0]const u8, sig: [*:0]const u8) jfieldID {
        return self._cJNIEnv.*.*.GetStaticFieldID.?(self._cJNIEnv, clazz, name, sig);
    }

    pub inline fn getStaticField(self: *const JNIEnv, clazz: jclass, comptime ReturnType: type, fieldID: jfieldID) ReturnType {
        return switch (ReturnType) {
            jobject => self._cJNIEnv.*.*.GetStaticObjectField.?(self._cJNIEnv, clazz, fieldID),
            jboolean => self._cJNIEnv.*.*.GetStaticBooleanField.?(self._cJNIEnv, clazz, fieldID),
            bool => jboolean2bool(self._cJNIEnv.*.*.GetStaticBooleanField.?(self._cJNIEnv, clazz, fieldID)),
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

    pub inline fn setStaticField(self: *const JNIEnv, clazz: jclass, comptime ReturnType: type, fieldID: jfieldID, val: ReturnType) void {
        return switch (ReturnType) {
            jobject => self._cJNIEnv.*.*.SetStaticObjectField.?(self._cJNIEnv, clazz, fieldID, val),
            jboolean => self._cJNIEnv.*.*.SetStaticBooleanField.?(self._cJNIEnv, clazz, fieldID, val),
            bool => self._cJNIEnv.*.*.SetStaticBooleanField.?(self._cJNIEnv, clazz, fieldID, bool2jboolean(val)),
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

    pub inline fn newString(self: *const JNIEnv, unicode: [*:0]const jchar, len: jsize) jstring {
        return self._cJNIEnv.*.*.NewString.?(self._cJNIEnv, unicode, len);
    }

    pub inline fn getStringLength(self: *const JNIEnv, str: jstring) jsize {
        return self._cJNIEnv.*.*.GetStringLength.?(self._cJNIEnv, str);
    }

    pub inline fn getStringChars(self: *const JNIEnv, str: jstring, isCopy: *bool) [*:0]const jchar {
        var isCopy_: jboolean = 0;
        const chars = self._cJNIEnv.*.*.GetStringChars.?(self._cJNIEnv, str, &isCopy_);
        isCopy.* = jboolean2bool(isCopy_);
        return chars;
    }

    pub inline fn releaseStringChars(self: *const JNIEnv, str: jstring, chars: [*:0]const jchar) void {
        return self._cJNIEnv.*.*.ReleaseStringChars.?(self._cJNIEnv, str, chars);
    }

    pub inline fn newStringUTF(self: *const JNIEnv, utf: [*:0]const u8) jstring {
        return self._cJNIEnv.*.*.NewStringUTF.?(self._cJNIEnv, utf);
    }

    pub inline fn getStringUTFLength(self: *const JNIEnv, str: jstring) jsize {
        return self._cJNIEnv.*.*.GetStringUTFLength.?(self._cJNIEnv, str);
    }

    pub inline fn getStringUTFChars(self: *const JNIEnv, str: jstring, isCopy: *bool) [*:0]const u8 {
        var isCopy_: jboolean = 0;
        const chars = self._cJNIEnv.*.*.GetStringUTFChars.?(self._cJNIEnv, str, &isCopy_);
        isCopy.* = jboolean2bool(isCopy_);
        return chars;
    }

    pub inline fn releaseStringUTFChars(self: *const JNIEnv, str: jstring, chars: [*:0]const u8) void {
        return self._cJNIEnv.*.*.ReleaseStringUTFChars.?(self._cJNIEnv, str, chars);
    }

    pub inline fn getArrayLength(self: *const JNIEnv, array: jarray) jsize {
        return self._cJNIEnv.*.*.GetArrayLength.?(self._cJNIEnv, array);
    }

    fn EleType2ArrayType(comptime ElementType: type) type {
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

    pub inline fn newPrimitiveArray(self: *const JNIEnv, comptime ElementType: type, len: jsize) EleType2ArrayType(ElementType) {
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

    pub inline fn newObjectArray(self: *const JNIEnv, len: jsize, elementClass: jclass, initialElement: jobject) jobjectArray {
        return self._cJNIEnv.*.*.NewObjectArray.?(self._cJNIEnv, len, elementClass, initialElement);
    }

    pub inline fn getObjectArrayElement(self: *const JNIEnv, array: jobjectArray, index: jsize) jobject {
        return self._cJNIEnv.*.*.GetObjectArrayElement.?(self._cJNIEnv, array, index);
    }

    pub inline fn setObjectArrayElement(self: *const JNIEnv, array: jobjectArray, index: jsize, val: jobject) void {
        return self._cJNIEnv.*.*.SetObjectArrayElement.?(self._cJNIEnv, array, index, val);
    }

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
        isCopy.* = jboolean2bool(isCopy_);
        return elems;
    }

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

    pub inline fn getArrayRegion(self: *const JNIEnv, ElementType: type, array: jarray, start: jsize, len: jsize, buf: [*]ElementType) void {
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

    pub inline fn setArrayRegion(self: *const JNIEnv, ElementType: type, array: jarray, start: jsize, len: jsize, buf: [*]const ElementType) void {
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

    pub inline fn registerNatives(self: *const JNIEnv, clazz: jclass, methods: [*]const cjni.JNINativeMethod, nMethods: jint) !void {
        return try checkError(self._cJNIEnv.*.*.RegisterNatives.?(self._cJNIEnv, clazz, methods, nMethods));
    }

    pub inline fn unregisterNatives(self: *const JNIEnv, clazz: jclass) !void {
        return try checkError(self._cJNIEnv.*.*.UnregisterNatives.?(self._cJNIEnv, clazz));
    }

    pub inline fn monitorEnter(self: *const JNIEnv, obj: jobject) !void {
        return try checkError(self._cJNIEnv.*.*.MonitorEnter.?(self._cJNIEnv, obj));
    }

    pub inline fn monitorExit(self: *const JNIEnv, obj: jobject) !void {
        return try checkError(self._cJNIEnv.*.*.MonitorExit.?(self._cJNIEnv, obj));
    }

    pub inline fn getJavaVM(self: *const JNIEnv, vm: *JavaVM) !void {
        return try checkError(self._cJNIEnv.*.*.GetJavaVM.?(self._cJNIEnv, &vm._cJavaVM));
    }

    pub inline fn getStringRegion(self: *const JNIEnv, str: jstring, start: jsize, len: jsize, buf: [*]u8) void {
        return self._cJNIEnv.*.*.GetStringRegion.?(self._cJNIEnv, str, start, len, buf);
    }

    pub inline fn getStringUTFRegion(self: *const JNIEnv, str: jstring, start: jsize, len: jsize, buf: [*]u8) void {
        return self._cJNIEnv.*.*.GetStringUTFRegion.?(self._cJNIEnv, str, start, len, buf);
    }

    pub inline fn getStringCritical(self: *const JNIEnv, str: jstring, isCopy: *bool) [*:0]const jchar {
        var isCopy_: jboolean = 0;
        const chars = self._cJNIEnv.*.*.GetStringCritical.?(self._cJNIEnv, str, &isCopy_);
        isCopy.* = jboolean2bool(isCopy_);
        return chars;
    }

    pub inline fn releaseStringCritical(self: *const JNIEnv, str: jstring, carray: [*:0]const jchar) void {
        return self._cJNIEnv.*.*.ReleaseStringCritical.?(self._cJNIEnv, str, carray);
    }

    pub inline fn newWeakGlobalRef(self: *const JNIEnv, obj: jobject) jweak {
        return self._cJNIEnv.*.*.NewWeakGlobalRef.?(self._cJNIEnv, obj);
    }

    pub inline fn deleteWeakGlobalRef(self: *const JNIEnv, obj: jweak) void {
        return self._cJNIEnv.*.*.DeleteWeakGlobalRef.?(self._cJNIEnv, obj);
    }

    pub inline fn exceptionCheck(self: *const JNIEnv) bool {
        return jboolean2bool(self._cJNIEnv.*.*.ExceptionCheck.?(self._cJNIEnv));
    }

    /// Make a direct java.nio.ByteBuffer from a pointer address, use @intFromPtr to get the address parameter
    pub inline fn newDirectByteBuffer(self: *const JNIEnv, address: usize, capacity: jlong) jobject {
        return self._cJNIEnv.*.*.NewDirectByteBuffer.?(self._cJNIEnv, @ptrFromInt(address), capacity);
    }

    /// Get the address of a direct java.nio.ByteBuffer, use @intFromPtr to convert the return value to a pointer
    pub inline fn getDirectBufferAddress(self: *const JNIEnv, buf: jobject) usize {
        return @intFromPtr(self._cJNIEnv.*.*.GetDirectBufferAddress.?(self._cJNIEnv, buf));
    }

    /// Get the capacity of a direct java.nio.ByteBuffer
    pub inline fn getDirectBufferCapacity(self: *const JNIEnv, buf: jobject) jlong {
        return self._cJNIEnv.*.*.GetDirectBufferCapacity.?(self._cJNIEnv, buf);
    }

    pub inline fn getObjectRefType(self: *const JNIEnv, obj: jobject) jobjectRefType {
        return self._cJNIEnv.*.*.GetObjectRefType.?(self._cJNIEnv, obj);
    }

    pub inline fn getModule(self: *const JNIEnv, clazz: jclass) jobject {
        return self._cJNIEnv.*.*.GetModule.?(self._cJNIEnv, clazz);
    }

    pub inline fn isVirtualThread(self: *const JNIEnv, obj: jobject) bool {
        return jboolean2bool(self._cJNIEnv.*.*.IsVirtualThread.?(self._cJNIEnv, obj));
    }
};
