struct U { vp:mat4x4<f32>, model:mat4x4<f32>, lightVP:mat4x4<f32>, eye:vec4<f32>, settings:vec4<f32>, paper:vec4<f32>, ink:vec4<f32> };
@group(0) @binding(0) var<uniform> u:U;
@group(1) @binding(0) var colorMap:texture_2d<f32>;
@group(1) @binding(1) var normalMap:texture_2d<f32>;
@group(1) @binding(2) var orm:texture_2d<f32>;
@group(1) @binding(3) var pattern:texture_2d<f32>;
@group(1) @binding(4) var mark:texture_2d<f32>;
@group(1) @binding(5) var smp:sampler;
@group(1) @binding(6) var shadowMap:texture_depth_2d;
@group(1) @binding(7) var shadowSampler:sampler_comparison;
// Bind raw and comparison depth views separately for Metal and GLSL backends.
@group(0) @binding(1) var shadowRaw:texture_depth_2d;
struct I { @location(0) p:vec3<f32>, @location(1) n:vec3<f32>, @location(2) uv:vec2<f32>, @location(3) kind:f32 };
struct V { @builtin(position) p:vec4<f32>, @location(0) world:vec3<f32>, @location(1) normal:vec3<f32>, @location(2) uv:vec2<f32>, @location(3) local:vec3<f32>, @location(4) @interpolate(flat) kind:f32, @location(5) shadow:vec4<f32> };
@vertex fn vs(i:I) -> V{
 var v:V;let w=u.model*vec4(i.p,1.);v.p=u.vp*w;v.world=w.xyz;v.normal=normalize((u.model*vec4(i.n,0.)).xyz);v.uv=i.uv;v.local=i.p;v.kind=i.kind;v.shadow=u.lightVP*w;return v;
}
// The shadow pass binds the same group(0) as the main pass. CLI 1.7 builds a pipeline's layout from the
// bindings its entry points use, so shadowVS touches all of them. No effect on the output.
fn keepLayout() -> f32{return f32(textureDimensions(shadowRaw).x)*0.;}
@vertex fn shadowVS(i:I) -> @builtin(position) vec4<f32>{let keepLayoutUse=keepLayout();return u.lightVP*u.model*vec4(i.p+keepLayoutUse,1.);}
fn visibility(p:vec4<f32>) -> f32{
 let q=p.xyz/p.w;let uv=q.xy*vec2(.5, - .5)+.5;let projected=vec3(uv,q.z);
 let dx=dpdx(projected);let dy=dpdy(projected);let determinant=dx.x*dy.y - dx.y*dy.x;
 var gradient=vec2(0.);if(abs(determinant)>.0000000001){gradient=clamp(vec2(dy.y*dx.z - dx.y*dy.z,dx.x*dy.z - dy.x*dx.z)/determinant,vec2( - 3.),vec2(3.));}
 if(any(uv<vec2(0.))||any(uv>vec2(1.))||q.z<0.||q.z>1.){return 1.;}
 let size=vec2<f32>(textureDimensions(shadowMap));let bias=.0003;
 var gap=0.;var blockers=0.;
 for(var i=0u;i<24u;i++){
  let a=f32(i)*2.399963;let offset=vec2(cos(a),sin(a))*sqrt((f32(i)+.5)/24.)*100./size;
  let coord=vec2<i32>(clamp((uv+offset)*size,vec2(0.),size - 1.));let z=textureLoad(shadowRaw,coord,0);
  let receiver=q.z+dot(gradient,offset);if(z<receiver - bias){gap+=(receiver - z)*6000.;blockers+=1.;}
 }
 let radius=clamp(gap/max(blockers,1.)*.95,2.,100.);var sum=0.;
 for(var i=0u;i<64u;i++){
  let a=f32(i)*2.399963;let offset=vec2(cos(a),sin(a))*sqrt((f32(i)+.5)/64.)*radius/size;
  sum+=textureSampleCompareLevel(shadowMap,shadowSampler,uv+offset,q.z+dot(gradient,offset) - bias);
 }
 return sum/64.;
}
fn segmentDistance(p:vec2<f32>,a:vec2<f32>,b:vec2<f32>) -> f32{let ab=b - a;return length(p - a - ab*clamp(dot(p - a,ab)/dot(ab,ab),0.,1.));}
fn knitHeight(p:vec2<f32>) -> f32{
 let warp=p+vec2(sin(p.y*2.7+p.x*.83),cos(p.x*1.7+p.y*.6))*.09;
 let cell=fract(warp+vec2(fract(floor(warp.y)*.5),0.)) - .5;
 let q=cell*vec2(4.3,3.6);let pore=exp( - dot(q,q)*1.6);
 let thread=.04*sin(p.x*38.+p.y*12.)*sin(p.y*25.);
 return 1. - pore+thread;
}
@fragment fn fs(v:V) -> @location(0) vec4<f32>{
 let src=textureSample(colorMap,smp,v.uv).rgb;let surface=textureSample(orm,smp,v.uv);let nm=textureSample(normalMap,smp,v.uv).xyz*2. - 1.;
 var n=normalize(v.normal);let dp1=dpdx(v.world);let dp2=dpdy(v.world);let duv1=dpdx(v.uv);let duv2=dpdy(v.uv);
 let p2=cross(dp2,n);let p1=cross(n,dp1);let tangent=p2*duv1.x+p1*duv2.x;let bitangent=p2*duv1.y+p1*duv2.y;
 let inv=inverseSqrt(max(max(dot(tangent,tangent),dot(bitangent,bitangent)),.000001));
 n=normalize(mat3x3(tangent*inv,bitangent*inv,n)*vec3(nm.xy*select(.8,1.2,v.kind<.5),nm.z));
 let luma=dot(src,vec3(.2126,.7152,.0722));
 let chroma=max(src.g,src.b) - src.r;let upper=smoothstep(.04,.16,chroma);
 let garmentUV=vec2(v.local.x*.88+v.local.y*.38+.75,atan2(v.local.z,v.local.y+.42)/3.14159265*.76+v.local.x*.27+.34)*u.settings.x*1.0;
 let art=textureSample(pattern,smp,garmentUV).rgb;
 // Object-space fibers remain stationary while the native Rive artwork animates.
 let knit=vec2(v.local.x*58.,atan2(v.local.z,v.local.y+.42)*30.+v.local.x*6.);
 let height=knitHeight(knit);let knitAA=1. - smoothstep(.65,1.35,max(fwidth(knit.x),fwidth(knit.y)));
 let grad=vec2(knitHeight(knit+vec2(.012,0.)) - height,knitHeight(knit+vec2(0.,.012)) - height)/.012;
 let kd1=dpdx(knit);let kd2=dpdy(knit);let kt=normalize(p2*kd1.x+p1*kd2.x);let kb=normalize(p2*kd1.y+p1*kd2.y);
 if(v.kind<.5){n=normalize(n - (kt*grad.x+kb*grad.y)*.052*knitAA*upper);}
 let fiber=clamp(.98+(luma - .28)*1.3,.68,1.1)*mix(1.,.58+.47*height,knitAA);
 var base=mix(src,art,upper);var rough=.95;
 if(v.kind>.5&&v.kind<1.5){base=vec3(.98,.975,.95);rough=.86;}
 if(v.kind>1.5&&v.kind<2.5){base=vec3(.87,.87,.83);rough=.24;}
 if(v.kind>2.5&&v.kind<3.5){base=vec3(.97,.975,.947)*clamp(.91+luma*.12,.9,1.);rough=.86;}
 if(v.kind>3.5){base=mix(u.paper.rgb,vec3(1.),.22);rough=.52;}
 let labelUV=vec2((v.local.x+.73)/.90,( - .07 - v.local.y)/.18);
 let label=textureSample(mark,smp,clamp(labelUV,vec2(0.),vec2(1.)));
 let within=step(0.,labelUV.x)*step(labelUV.x,1.)*step(0.,labelUV.y)*step(labelUV.y,1.)*smoothstep(.14,.24,abs(v.local.z));
 if(v.kind<.5){base=mix(base,label.rgb/max(label.a,.001),label.a*within*upper);}
 if(v.kind<.5){base*=mix(1.,fiber,upper);}
 let light=normalize(vec3(1300.,2760.,2300.));let fill=normalize(vec3(.8,.25,.6));let view=normalize(u.eye.xyz - v.world);let half=normalize(view+light);
 let vis=visibility(v.shadow);let ao=mix(.30,1.,surface.r);
 let diffuse=.29+1.10*max(dot(n,light),0.)*vis+.14*max(dot(n,fill),0.)+.12*max(dot(n,normalize(vec3( - 1.,.2,.7))),0.);
 let spec=pow(max(dot(n,half),0.),mix(90.,18.,rough))*(1. - rough)*.32*vis;
 let rim=pow(1. - max(dot(n,view),0.),4.)*.035;
 if(u.settings.y>.5&&u.settings.y<1.5&&v.kind<.5){let x= - 1.+(u.settings.y - .5)*2.4;let front=exp( - pow((v.local.x - x)*12.,2.))*.17*upper;base=mix(base,vec3(1.),front);}
 let linear=pow(max(base,vec3(.001)),vec3(2.2));
 return vec4(pow(max(linear*diffuse*ao+vec3(spec+rim),vec3(0.)),vec3(1./2.2)),1.);
}
