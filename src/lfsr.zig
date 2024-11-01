const std = @import("std");
const testing = std.testing;
const BoundedArray = std.BoundedArray;

const rotr = std.math.rotr;

pub const InitErrors = error {
    SeedIsZero,
    TapsMustHaveMsbSet
};

/// This returns a structure to generate LFSRs outputing values as T.
pub fn LFSR(T: type) type {
    comptime {
        if(@typeInfo(T)) {
            switch (@typeInfo(T)) {
                .Int => |Ts| {
                    if(Ts.signedness == .signed) {
                        @compileError("outputType is a signed integer, only unsigned integers are supported.");
                    }
                },
                else => {
                    @compileError("outputType can only accept unsigned integers.");
                }
            }
        }
    }
 
    return struct {
        const bSize = @bitSizeOf(T);
        const Self = @This();

        /// Internal structure keeping the logic separate.
        const Internal = struct {
            taps : T,
            next: T,

            pub fn init(seed: T, tapValue: T) Internal {
                var item = Internal{
                    .next = seed,
                    .taps = tapValue
                };

                item.calcNext();

                return item;
            }

            pub fn calcNext(self: *Internal) void {
                const previous = self.next;
                const bit : T = @popCount(previous & self.taps);
                self.next = rotr(T, ((previous & ~@as(T, 1)) | (bit & 1)), 1);
            }
        };
    
        /// Internals of the LFSR are inside this field.
        internals : Internal,
        
        /// Initializes a new LFSR.
        /// 
        /// seed must be a non-zero value
        /// 
        /// taps is a value representing the feedback polinomial of the taps for the lfsr
        /// 
        /// Example, for the polynomial x^3 + x^2 + 1, the tap value would be 0b110. 
        /// 
        /// referring to https://en.wikipedia.org/wiki/Linear-feedback_shift_register#Example_polynomials_for_maximal_LFSRs
        /// 
        /// Reminder that the most significant bit of the tap must always be set, meaning the simplest tap is (1 << (@bitSizeOf(u8) - 1))
        pub fn init(seed: T, taps: T) InitErrors!Self {
            if(seed == 0) {
                return InitErrors.SeedIsZero;
            }

            const reversed = @bitReverse(taps);
            if((reversed & 1) == 0) {
                return InitErrors.TapsMustHaveMsbSet;
            }

            return Self{
                .internals = Internal.init(seed, reversed)
            };
            
        }

        /// Your only interface to get the next value in the LFSR.
        pub fn next(self: *Self) T {
            defer self.internals.calcNext();
            return self.internals.next;
        }
    };
}

const meta = std.meta;

fn testCase(outType: type, tap: outType) !void {
    const T = LFSR(outType);
    var i = std.math.pow(meta.Int(.unsigned, @bitSizeOf(outType) + 1), 2, @bitSizeOf(outType)) - 2;
    var lfsr = try T.init(1, tap);
    while(i > 0) : (i -= 1) {
        _ = lfsr.next();
    }
    try testing.expectEqual(@as(outType, 1), lfsr.internals.next);
}

test "example" {
    try testCase(u2, 0x3);
    try testCase(u3, 0x6);
    try testCase(u4, 0xC);
    try testCase(u5, 0x14);
    try testCase(u6, 0x30);
    try testCase(u7, 0x60);
    try testCase(u8, 0xB8);
    try testCase(u16, 0xfff6);
}

test "simple" {
    var lfsr = try LFSR(u4).init(1, 0b1101);
    try testing.expectEqual(@as(u4, 0b1000), lfsr.next());
    try testing.expectEqual(@as(u4, 0b1100), lfsr.next());
    try testing.expectEqual(@as(u4, 0b1110), lfsr.next());
    try testing.expectEqual(@as(u4, 0b0111), lfsr.next());
    try testing.expectEqual(@as(u4, 0b0011), lfsr.next());
    try testing.expectEqual(@as(u4, 0b0001), lfsr.next());
}

test "errors" {
    const T = LFSR(u8);
    _ = try T.init(1, (1 << (@bitSizeOf(u8) - 1)));
    try testing.expectError(InitErrors.SeedIsZero, T.init(0, 0xB8));
    try testing.expectError(InitErrors.TapsMustHaveMsbSet, T.init(1, 0));
}