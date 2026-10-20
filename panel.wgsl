struct U { vp:mat4x4<f32>, model:mat4x4<f32>, lightVP:mat4x4<f32>, shape:vec4<f32>, clock:vec4<f32>, a:vec4<f32>, b:vec4<f32> };
@group(0) @binding(0) var<uniform> u:U;
@group(0) @binding(1) var ui:texture_2d<f32>;
@group(0) @binding(2) var print:texture_2d<f32>;
@group(0) @binding(3) var smp:sampler;
@group(1) @binding(0) var shadowMap:texture_depth_2d;
@group(1) @binding(1) var shadowSampler:sampler_comparison;
@group(1) @binding(2) var shadowRaw:texture_depth_2d;
fn smoother(t0:f32) -> f32{let t=clamp(t0,0.,1.);return t*t*t*(10.+t*( - 15.+6.*t));}
// Position, tangent and curvature match at the straight/roll/floor transitions.
// The CPU inverse picker in surfaces.as evaluates this same analytic surface.
fn paper(uv:vec2<f32>) -> vec3<f32>{
 let first= - .12;let last=1.14;let span=last - first;let t=clamp((uv.y - first)/span,0.,1.);
 let t2=t*t;let t3=t2*t;let t4=t3*t;let t5=t4*t;
 let blend=10.*t3 - 15.*t4+6.*t5;let incoming=t - 6.*t3+8.*t4 - 3.*t5;let outgoing= - 4.*t3+7.*t4 - 3.*t5;
 let floor=329./980.;let radius=330./980.;let b=u.shape.z;
 var cy=u.shape.y*((first - .5)+(floor - (first - .5))*blend+span*incoming);
 if(uv.y<first){cy=(uv.y - .5)*u.shape.y;}
 let cz=u.shape.y*(radius*blend+.62*(span*outgoing+max(uv.y - last,0.)));
 let q=uv.y/1.24;let one=1. - q;
 let lateral=3.*one*one*q*20.+3.*one*q*q*190.+q*q*q*620.;
 let top=.40*log(1.+exp((.2 - uv.y)/.080));
 let decay=exp( - 2.*top/1.2);let shoulder=1.2*(1. - decay)/(1.+decay);
 let upperSweep=45.*(1. - uv.x)*(1. - smoother((uv.y+.12)/1.24));
 return vec3((uv.x - .5)*u.shape.x+b*(lateral - upperSweep),
 (uv.y - .5)*u.shape.y+b*(cy - (uv.y - .5)*u.shape.y)+b*60.*uv.x*shoulder*shoulder,
 b*(cz - 110.*top*top*uv.x*uv.x+25.*sin(uv.y*3.14159265)+300.*(1. - uv.x)*smoother((uv.y+.10)/1.30)));
}
fn rim(x:f32) -> f32{let t=clamp((x - .67)/.33,0.,1.);return - .20+.26*(1. - sqrt(max(1. - t*t,0.)));}
fn surface(uv:vec2<f32>)  ->  vec3<f32>{
 let kind=u.shape.w;let t=uv.y;let x=uv.x  -  .5;
 if(kind<.5){return paper(uv);}
 if(kind>2.5){
  let a=u.a.xyz;let b=u.b.xyz;let axis=normalize(vec3(  -  (b.y  -  a.y),b.x  -  a.x,0.));
  let center=mix(a,b,t)+vec3(0.,sin(t*3.14159265)*45.,sin(t*3.14159265)*90.);
  return center+axis*x*(6.+28.*sin(t*3.14159265));
 }
 let bottom=kind>1.5;let endV=select( - .20,1.24,bottom);let anchor=paper(vec2(.5,endV));
 let edge=paper(vec2(uv.x,select(rim(uv.x),endV,bottom))) - anchor - vec3(x*u.shape.x,0.,0.);
 let span=mix(u.shape.x,select(280.,800.,bottom),smoother(t/.65));
 if(bottom){
  let turn=atan2(2600.*t,600.);
  let center=anchor+vec3(1400.*t*t, - 6.*sin(t*3.14159265)*clamp(u.shape.z,0.,1.), - 380.*t);
  return center+vec3(cos(turn)*x*span,0., - sin(turn)*x*span)+edge*(1. - smoother(t/.35));
 }
 let q=1. - t;let wave=sin((t - .12)*6.2831853)*sin(t*3.14159265);
 let center=anchor+vec3(3.*q*t*t*950.+t*t*t*1650.,3.*q*q*t*( - 300.)+3.*q*t*t*300.+t*t*t*410.+155.*wave, - 320.*sin(t*3.14159265)+210.*sin(t*9.424778)*sin(t*3.14159265));
 let dx=5700.*q*t+2100.*t*t;
 let dy= - 900.*q*q+3600.*q*t+330.*t*t+155.*(6.2831853*cos((t - .12)*6.2831853)*sin(t*3.14159265)+3.14159265*sin((t - .12)*6.2831853)*cos(t*3.14159265));
 let turn=atan2(dx, - dy);let twist=.75*sin(t*6.2831853+.4)*sin(t*3.14159265);
 let across=vec3(cos(turn)*cos(twist),sin(turn)*cos(twist),sin(twist));
 let extension=center+across*x*span+vec3(0.,0.,sin(x*3.14159265)*sin(t*3.14159265)*30.)+edge*(1. - smoother(t/.35));
 // The rear extension leaves the shoulder in its existing direction and curvature.
 return mix(paper(vec2(uv.x,rim(uv.x) - t*.70)),extension,smoother(t/.35));
}
fn texcoord(i:u32)  ->  vec2<f32>{
 let c=array<vec2<f32>,6>(vec2(0.,0.),vec2(1.,0.),vec2(0.,1.),vec2(0.,1.),vec2(1.,0.),vec2(1.,1.));
 let cell=i/6u;var uv=(vec2(f32(cell%128u),f32(cell/128u))+c[i%6u])/vec2(128.,192.);if(uv.x>.67){uv.x=.67+.33*sin((uv.x - .67)/.33*1.570796327);}
 if(u.shape.w<.5){let first=select(rim(uv.x),0.,u.shape.y<800.);uv.y=mix(first,mix(1.,1.24,clamp(u.shape.z,0.,1.)),uv.y);}return uv;
}
fn worldPoint(uv:vec2<f32>) -> vec3<f32>{
 var p=(u.model*vec4(surface(uv),1.)).xyz;
 if(u.shape.w>.5&&u.shape.w<1.5){let depth=select(1.+.50*smoother((uv.y - .02)/.48),1.6+.7*smoother(uv.y/.5),u.shape.y<800.);let neutralEye=vec3(0.,0.,u.a.w);p=neutralEye+(p - neutralEye)*depth;}
 return p;
}
struct V { @builtin(position) pos:vec4<f32>, @location(0) uv:vec2<f32>, @location(1) normal:vec3<f32>, @location(2) shadow:vec4<f32>, @location(3) world:vec3<f32> };
@vertex fn vs(@builtin(vertex_index) i:u32) -> V{
 let uv=texcoord(i);let p=worldPoint(uv);let dx=worldPoint(uv+vec2(.0005,0.)) - worldPoint(uv - vec2(.0005,0.));let dy=worldPoint(uv+vec2(0.,.0005)) - worldPoint(uv - vec2(0.,.0005));
 var v:V;v.pos=u.vp*vec4(p,1.);v.uv=uv;v.normal=normalize(cross(dy,dx));v.shadow=u.lightVP*vec4(p,1.);v.world=p;return v;
}
// The shadow pass binds the same group(0) as the main pass. CLI 1.7 builds a pipeline's layout from the
// bindings its entry points use, so shadowVS touches all of them. No effect on the output.
fn keepLayout() -> f32{return (f32(textureDimensions(ui).x+textureDimensions(print).x)+textureSampleLevel(ui,smp,vec2(0.),0.).x)*0.;}
@vertex fn shadowVS(@builtin(vertex_index) i:u32) -> @builtin(position) vec4<f32>{let keepLayoutUse=keepLayout();return u.lightVP*vec4(worldPoint(texcoord(i))+keepLayoutUse,1.);}
// Blocker search covers the filter footprint; smaller searches produce a hard silhouette outside soft shadows.
// Curved receivers use a smaller footprint to limit the error of receiver-plane depth correction.
fn visibility(p:vec4<f32>) -> f32{
 let q=p.xyz/p.w;let uv=q.xy*vec2(.5, - .5)+.5;let projected=vec3(uv,q.z);
 let dx=dpdx(projected);let dy=dpdy(projected);let determinant=dx.x*dy.y - dx.y*dy.x;
 var gradient=vec2(0.);if(abs(determinant)>.0000000001){gradient=clamp(vec2(dy.y*dx.z - dx.y*dy.z,dx.x*dy.z - dy.x*dx.z)/determinant,vec2( - 3.),vec2(3.));}
 if(any(uv<vec2(0.))||any(uv>vec2(1.))||q.z<0.||q.z>1.){return 1.;}
 let size=vec2<f32>(textureDimensions(shadowMap));let bias=select(.0006,.003,u.shape.w>.5&&u.shape.w<1.5);
 let extent=select(40.,8.,u.shape.w>.5&&u.shape.w<1.5);
 var gap=0.;var blockers=0.;
 for(var i=0u;i<24u;i++){
  let a=f32(i)*2.399963;let offset=vec2(cos(a),sin(a))*sqrt((f32(i)+.5)/24.)*extent/size;
  let coord=vec2<i32>(clamp((uv+offset)*size,vec2(0.),size - 1.));let z=textureLoad(shadowRaw,coord,0);
  let receiver=q.z+dot(gradient,offset);if(z<receiver - bias){gap+=(receiver - z)*6000.;blockers+=1.;}
 }
 let radius=clamp(gap/max(blockers,1.)*.95,2.,extent);var sum=0.;
 for(var i=0u;i<64u;i++){
  let a=f32(i)*2.399963;let offset=vec2(cos(a),sin(a))*sqrt((f32(i)+.5)/64.)*radius/size;
  sum+=textureSampleCompareLevel(shadowMap,shadowSampler,uv+offset,q.z+dot(gradient,offset) - bias);
 }
 return sum/64.;
}
@fragment fn fs(v:V)  ->  @location(0) vec4<f32>{
 var c=textureSample(ui,smp,v.uv);
 if(u.shape.w>.5){let tex=vec2(v.uv.y*3.6,v.uv.x*.85+v.uv.y*.27);c=textureSampleGrad(print,smp,fract(tex),dpdx(tex),dpdy(tex));}
 var n=normalize(v.normal);let view=normalize(u.a.xyz - v.world);if(dot(n,view)<0.){n= - n;}
 let key=normalize(vec3(1300.,2760.,2300.));let lambert=max(dot(n,key),0.);let vis=visibility(v.shadow);
 var energy=vec3(.26,.265,.225)+vec3(1.,.98,.94)*(.72*lambert*vis)+vec3(.18,.17,.17)*max(dot(n,normalize(vec3( - 1.,.45,1.5))),0.)+vec3(.045,.048,.016)*max(n.y,0.);
 if(u.shape.w>.5&&u.shape.w<1.5){energy+=vec3(.23,.22,.20);}
 let half=normalize(key+view);let spec=pow(max(dot(n,half),0.),select(20.,32.,u.shape.w>.5))*select(.07,.13,u.shape.w>.5)*vis;
 let fiber=1.+select(.004,.018,u.shape.w>.5)*sin(v.uv.x*1900.)*sin(v.uv.y*1500.);
 let rgb=pow(max(pow(max(c.rgb,vec3(.001)),vec3(2.2))*energy*fiber+vec3(spec),vec3(0.)),vec3(1./2.2));
 var alpha=c.a*u.clock.y;
 if(u.shape.w>2.5){let band=(1. - smoothstep(u.clock.z,u.clock.z+.15,v.uv.y))*smoothstep(u.clock.z - .45,u.clock.z - .15,v.uv.y);alpha*=sin(clamp(u.clock.z/1.5,0.,1.)*3.14159265)*mix(.25,1.,band);}
 return vec4(rgb,c.a)*u.clock.y*select(1.,alpha/max(c.a*u.clock.y,.001),u.shape.w>2.5);
}
