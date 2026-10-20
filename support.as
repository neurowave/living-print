import { Vector } from "rive/vector";
import { Mat4 } from "rive/mat4";
import { ViewModel, PropertyNumber, PropertyBoolean, PropertyString, PropertyColor } from "rive/data";
import { Buffer } from "rive/buffer";

export function clamp(v: f64, lo: f64, hi: f64): f64 { return Math.max(lo, Math.min(hi, v)); }
export function xy(x: f64, y: f64): Vector { return Vector.xy(<f32>x, <f32>y); }
export function xyz(x: f64, y: f64, z: f64): Vector { return Vector.xyz(<f32>x, <f32>y, <f32>z); }
export function translate(x: f64, y: f64, z: f64): Mat4 { return Mat4.fromTranslation(<f32>x, <f32>y, <f32>z); }
export function scale(x: f64, y: f64, z: f64): Mat4 { return Mat4.fromScale(<f32>x, <f32>y, <f32>z); }
export function floats(buf: ArrayBuffer, offset: i32, values: f64[]): void {
    for (let i = 0; i < values.length; i++) Buffer.writef32(buf, offset + i * 4, values[i]);
}
export class Hit {
    position: Vector;
    constructor(p: Vector) { this.position = p; }
    get x(): f64 { return this.position.x; }
    get y(): f64 { return this.position.y; }
}
// Cache native property handles rather than creating wrappers on every frame.
export class Config {
    vm: ViewModel;
    numbers: Map<string, PropertyNumber> = new Map<string, PropertyNumber>();
    booleans: Map<string, PropertyBoolean> = new Map<string, PropertyBoolean>();
    strings: Map<string, PropertyString> = new Map<string, PropertyString>();
    colors: Map<string, PropertyColor> = new Map<string, PropertyColor>();
    constructor(vm: ViewModel) { this.vm = vm; }
    n(name: string): PropertyNumber {
        if (!this.numbers.has(name)) this.numbers.set(name, this.vm.getNumber(name)!);
        return this.numbers.get(name);
    }
    b(name: string): PropertyBoolean {
        if (!this.booleans.has(name)) this.booleans.set(name, this.vm.getBoolean(name)!);
        return this.booleans.get(name);
    }
    s(name: string): PropertyString {
        if (!this.strings.has(name)) this.strings.set(name, this.vm.getString(name)!);
        return this.strings.get(name);
    }
    c(name: string): PropertyColor {
        if (!this.colors.has(name)) this.colors.set(name, this.vm.getColor(name)!);
        return this.colors.get(name);
    }
}
