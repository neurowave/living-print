import { Vector } from "rive/vector";
import { Mat4 } from "rive/mat4";
import { clamp, xy, xyz, Hit } from "./support";

export class Surface {
    w: f64; h: f64; bend: f64 = 1;
    mvp: Mat4 = Mat4.identity();
    model: Mat4 = Mat4.identity();
    constructor(w: f64, h: f64) { this.w = w; this.h = h; }
}
export class Camera {
    eye: Vector; vp: Mat4; distance: f64;
    constructor(eye: Vector, vp: Mat4, distance: f64) {
        this.eye = eye; this.vp = vp; this.distance = distance;
    }
}
export function smoother(t: f64): f64 {
    t = clamp(t, 0, 1); return t*t*t*(10+t*(-15+6*t));
}
export function view(w: f64, h: f64, x: f64, y: f64): Camera {
    let unit = Math.min(w/1600, h/900), distance = 1800*Math.max(unit, .6);
    let compact = w/h < 1.12;
    let yaw = clamp(x,-1,1)*(compact ? .04 : .10);
    let pitch = -clamp(y,-1,1)*(compact ? .025 : .06);
    let eye = xyz(distance*Math.sin(yaw)*Math.cos(pitch), distance*Math.sin(pitch), distance*Math.cos(yaw)*Math.cos(pitch));
    let vp = Mat4.perspective(<f32>(2*Math.atan(h/(2*distance))), <f32>(w/h), 1, 9000)*Mat4.lookAtVector(eye, xyz(0,0,0), xyz(0,1,0));
    return new Camera(eye, vp, distance);
}
export function point(u: f64, v: f64, w: f64, h: f64, b: f64): Vector {
    // Keep synchronized with paper() in panel.wgsl.
    let first: f64 = -.12, last: f64 = 1.14, span = last-first;
    let t = clamp((v-first)/span,0,1), t2=t*t, t3=t2*t, t4=t3*t, t5=t4*t;
    let blend=10*t3-15*t4+6*t5, incoming=t-6*t3+8*t4-3*t5, outgoing=-4*t3+7*t4-3*t5;
    let floor: f64=329.0/980.0, radius: f64=330.0/980.0;
    let cy=h*((first-.5)+(floor-(first-.5))*blend+span*incoming);
    if (v<first) cy=(v-.5)*h;
    let cz=h*(radius*blend+.62*(span*outgoing+Math.max(v-last,0)));
    let q=v/1.24, one=1-q;
    let lateral=3*one*one*q*20+3*one*q*q*190+q*q*q*620;
    let top=.40*Math.log(1+Math.exp((.2-v)/.080));
    let decay=Math.exp(-2*top/1.2), shoulder=1.2*(1-decay)/(1+decay);
    let upperSweep=45*(1-u)*(1-smoother((v+.12)/1.24));
    return xyz((u-.5)*w+b*(lateral-upperSweep),
        (v-.5)*h+b*(cy-(v-.5)*h)+b*60*u*shoulder*shoulder,
        b*(cz-110*top*top*u*u+25*Math.sin(v*Math.PI)+300*(1-u)*smoother((v+.10)/1.30)));
}
export function project(p: Surface, u: f64, v: f64, w: f64, h: f64): Vector {
    let q=point(u,v,p.w,p.h,p.bend), c=p.mvp.transformPoint(q.x,q.y,q.z);
    return xy((c.x+1)*w*.5,(1-c.y)*h*.5);
}
export function hit(p: Surface, pos: Vector, w: f64, h: f64): Hit? {
    let inv=p.mvp.invert(); if (inv==null) return null;
    let a=inv.transformPoint(<f32>(pos.x/w*2-1),<f32>(1-pos.y/h*2),0);
    let z=inv.transformPoint(<f32>(pos.x/w*2-1),<f32>(1-pos.y/h*2),1), d=z-a;
    if (Math.abs(d.z)<.000001) return null;
    let t: f64=-a.z/d.z, u=(a.x+d.x*t)/p.w+.5, v=(a.y+d.y*t)/p.h+.5;
    for (let i=0; i<10; i++) {
        let q=project(p,u,v,w,h), e=q-pos;
        if (e.lengthSquared()<.02) return new Hit(xy(u*p.w,v*p.h));
        let du=(project(p,u+.001,v,w,h)-q)/<f32>.001, dv=(project(p,u,v+.001,w,h)-q)/<f32>.001;
        let det=du.x*dv.y-du.y*dv.x; if (Math.abs(det)<.00001) return null;
        u-=clamp((e.x*dv.y-e.y*dv.x)/det,-.25,.25);
        v-=clamp((du.x*e.y-du.y*e.x)/det,-.25,.25);
    }
    let e=project(p,u,v,w,h)-pos;
    return e.lengthSquared()<4 ? new Hit(xy(u*p.w,v*p.h)) : null;
}
