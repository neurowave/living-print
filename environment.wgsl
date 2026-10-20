struct U { vp:mat4x4<f32>, lightVP:mat4x4<f32>, eye:vec4<f32>, stage:vec4<f32>, shape:vec4<f32>, ground:vec4<f32> };
@group(0) @binding(0) var<uniform> u:U;
@group(0) @binding(1) var lettering:texture_2d<f32>;
@group(0) @binding(2) var smp:sampler;
@group(1) @binding(0) var shadowMap:texture_depth_2d;
@group(1) @binding(1) var shadowSampler:sampler_comparison;
@group(1) @binding(2) var shadowRaw:texture_depth_2d;
struct V { @builtin(position) pos:vec4<f32>, @location(0) normal:vec3<f32>, @location(1) world:vec3<f32>, @location(2) shadow:vec4<f32>, @location(3) uv:vec2<f32> };
fn vertex(i:u32)  ->  V{
 var p:vec3<f32>;var n=vec3(0.,1.,0.);var uv=vec2(  -  2.);
 if(u.shape.z<.5){let a=array<vec2<f32>,6>(vec2(  -  1.,  -  1.),vec2(1.,  -  1.),vec2(  -  1.,1.),vec2(  -  1.,1.),vec2(1.,  -  1.),vec2(1.,1.));p=vec3(a[i%6u].x*6000.,u.ground.x,a[i%6u].y*6000.);}
 else {
  let seg=i/33u;let k=i%33u;let edge=u.shape.y*.19;
  var angle=0.;
  if(k<3u){
   angle=(f32(seg)+select(0.,1.,k==2u))/128.*6.2831853;
   p=u.stage.xyz;if(k>0u){p+=vec3(cos(angle)*(u.stage.w - edge),0.,sin(angle)*(u.shape.x - edge));}
  }else{
   let band=(k - 3u)/6u;let corner=array<vec2<u32>,6>(vec2(0u,0u),vec2(1u,0u),vec2(0u,1u),vec2(0u,1u),vec2(1u,0u),vec2(1u,1u));let c=corner[(k - 3u)%6u];let ring=band+c.y;
   let inset=array<f32,6>(1.,.293,0.,0.,.293,1.);
   let ys=array<f32,6>(0.,edge*.293,edge,u.shape.y - edge,u.shape.y - edge*.293,u.shape.y);
   let radial=array<f32,6>(0.,.707,1.,1.,.707,0.);let vertical=array<f32,6>(1.,.707,0.,0., - .707, - 1.);
   angle=(f32(seg)+f32(c.x))/128.*6.2831853;
   p=u.stage.xyz+vec3(cos(angle)*(u.stage.w - edge*inset[ring]), - ys[ring],sin(angle)*(u.shape.x - edge*inset[ring]));
   let side=normalize(vec3(cos(angle)/u.stage.w,0.,sin(angle)/u.shape.x));n=side*radial[ring]+vec3(0.,vertical[ring],0.);
   // Center lettering in the resting composition; keep it attached as the camera orbits.
   let center=atan2((u.eye.w - u.stage.z)*u.stage.w, - u.stage.x*u.shape.x);
   let delta=atan2(sin(angle - center),cos(angle - center));
   uv=vec2(.5 - delta/3.14159265*2.,ys[ring]/u.shape.y);
  }
 }
 var v:V;v.pos=u.vp*vec4(p,1.);v.normal=n;v.world=p;v.shadow=u.lightVP*vec4(p,1.);v.uv=uv;return v;
}
@vertex fn vs(@builtin(vertex_index) i:u32)  ->  V{return vertex(i);}
// The shadow pass binds the same group(0) as the main pass. CLI 1.7 builds a pipeline's layout from the
// bindings its entry points use, so shadowVS touches all of them. No effect on the output.
fn keepLayout() -> f32{return (f32(textureDimensions(lettering).x)+textureSampleLevel(lettering,smp,vec2(0.),0.).x)*0.;}
@vertex fn shadowVS(@builtin(vertex_index) i:u32)  ->  @builtin(position) vec4<f32>{let keepLayoutUse=keepLayout();return vertex(i).shadow+vec4(keepLayoutUse);}
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
@fragment fn fs(v:V)  ->  @location(0) vec4<f32>{
 let light=max(dot(normalize(v.normal),normalize(vec3(1300.,2760.,2300.))),0.);
 let vis=visibility(v.shadow);
 var base=vec3(.91,.97,.40);
 if(u.shape.z<.5){base=mix(vec3(.955,.978,.62),vec3(.975,.99,.72),clamp(  -  v.world.z/1800.,0.,1.));}
 else {base=mix(vec3(.86,.90,.38),vec3(.92,.98,.44),smoothstep(  -  .1,.8,v.normal.y));
  let label=textureSample(lettering,smp,clamp(v.uv,vec2(0.),vec2(1.)));
  if(all(v.uv>=vec2(0.))&&all(v.uv<=vec2(1.))){base=mix(base,label.rgb/max(label.a,.001),label.a);}
 }
 let n=normalize(v.normal);let key=normalize(vec3(1300.,2760.,2300.));let view=normalize(u.eye.xyz - v.world);let half=normalize(key+view);
 let ambient=vec3(.30,.315,.15);let energy=ambient+vec3(1.,.985,.94)*(.95*light*vis);
 var color=pow(max(pow(base,vec3(2.2))*energy,vec3(0.)),vec3(1./2.2));
 if(u.shape.z>.5){let sheen=pow(max(dot(n,half),0.),32.)*.16*vis;color+=vec3(sheen);}
 if(u.shape.z<.5){let xy=v.pos.xy/u.ground.yz;let halo=exp( - dot((xy - vec2(.77,.35))*vec2(1.4,1.),(xy - vec2(.77,.35))*vec2(1.4,1.))*4.)*.04;let sky=mix(vec3(.987,.994,.76),vec3(.958,.986,.58),clamp(xy.y*.8+xy.x*.25,0.,1.))+vec3(halo*.1,halo*.4, - halo*.3);color=mix(color,sky,smoothstep(1500.,5000., - v.world.z));}

 return vec4(color,1.);
}
