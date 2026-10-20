struct U { size:vec4<f32>, composition:vec4<f32> };
@group(0) @binding(0) var<uniform> u:U;
struct V { @builtin(position) p:vec4<f32>, @location(0) uv:vec2<f32> };
@vertex fn vs(@builtin(vertex_index) i:u32) -> V{
 let q=array<vec2<f32>,3>(vec2( - 1., - 1.),vec2(3., - 1.),vec2( - 1.,3.));var v:V;v.p=vec4(q[i],.9999,1.);v.uv=q[i]*vec2(.5, - .5)+.5;return v;
}
@fragment fn fs(v:V) -> @location(0) vec4<f32>{
 let uv=v.uv;
 let warm=vec3(.958,.986,.58);let bright=vec3(.987,.994,.76);
 var c=mix(bright,warm,clamp(uv.y*.8+uv.x*.25,0.,1.));
 let d=(uv - u.composition.xy)/u.composition.zw;
 let shadow=exp( - dot(d,d)*3.3)*.0;
 let halo=exp( - dot((uv - vec2(.77,.35))*vec2(1.4,1.),(uv - vec2(.77,.35))*vec2(1.4,1.))*4.)*.04;
 c=c*(1. - shadow)+vec3(halo*.1,halo*.4, - halo*.3);
 return vec4(c,1.);
}
