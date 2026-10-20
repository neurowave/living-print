import { Context } from "rive/host";
import { Canvas } from "rive/canvas";
import { Artboard } from "rive/artboard";
import { Mat4 } from "rive/mat4";
import { Vector } from "rive/vector";
import { GPUBuffer, GPUBindGroup, GPUBindGroupUBO, GPUBindGroupTexture, GPUBindGroupSampler, GPUTexture, GPUTextureView, GPUTextureViewDesc, GPUSampler, GPUPipeline, GPURenderPass } from "rive/gpu";
import { BufferUsage, TextureFormat, TextureAspect } from "rive/gpu_enums";
import { texture, sampler, makePipeline } from "./gpu_helpers";
import { Surface } from "./surfaces";
import { xyz, floats } from "./support";

export class Sheet extends Surface {
    art: Artboard?; canvas: Canvas; kind: i32;
    ubo: GPUBuffer = new GPUBuffer(BufferUsage.uniform,256);
    buf: ArrayBuffer = new ArrayBuffer(256);
    bg: GPUBindGroup?=null; shadowBg: GPUBindGroup?=null;
    constructor(art: Artboard?,canvas: Canvas,w:f64,h:f64,kind:i32) {
        super(w,h); this.art=art; this.canvas=canvas; this.kind=kind;
    }
}
class Environment {
    kind:i32;
    ubo:GPUBuffer=new GPUBuffer(BufferUsage.uniform,192);
    buf:ArrayBuffer=new ArrayBuffer(192);
    bg:GPUBindGroup; shadowBg:GPUBindGroup;
    constructor(stage:Stage,kind:i32) {
        this.kind=kind;
        let ubos=[new GPUBindGroupUBO(0,this.ubo)];
        let textures=[new GPUBindGroupTexture(1,stage.lettering.image.view()!)];
        let samplers=[new GPUBindGroupSampler(2,stage.sampler)];
        this.bg=new GPUBindGroup(stage.environment.getBindGroupLayout(0),ubos,textures,samplers);
        this.shadowBg=new GPUBindGroup(stage.environmentShadow.getBindGroupLayout(0),ubos,textures,samplers);
    }
}
export class Stage {
    pattern:Canvas; lettering:Canvas;
    shadow:GPUTexture; shadowView:GPUTextureView;
    // 1x1 depth stand-in for the shoe's shadow pass, which can't read the shadow map it writes.
    standIn:GPUTexture; standInView:GPUTextureView;
    compare:GPUSampler=sampler(false,true); sampler:GPUSampler=sampler();
    panel:GPUPipeline; panelShadow:GPUPipeline; environment:GPUPipeline; environmentShadow:GPUPipeline;
    panelLight:GPUBindGroup; environmentLight:GPUBindGroup;
    floor:Environment; plinth:Environment;
    lightVP:Mat4=Mat4.identity();
    constructor(context:Context,pattern:Canvas,lettering:Canvas) {
        this.pattern=pattern; this.lettering=lettering;
        this.shadow=texture(4096,4096,TextureFormat.depth32float);
        let desc=new GPUTextureViewDesc();desc.aspect=TextureAspect.depthOnly;this.shadowView=this.shadow.view(desc);
        this.standIn=texture(1,1,TextureFormat.depth32float);this.standInView=this.standIn.view(desc);
        let shader=context.shader("panel")!,env=context.shader("environment")!;
        this.panel=makePipeline(shader,false,true);this.panelShadow=makePipeline(shader,true);
        this.environment=makePipeline(env);this.environmentShadow=makePipeline(env,true);
        let textures=[new GPUBindGroupTexture(0,this.shadowView),new GPUBindGroupTexture(2,this.shadowView)];
        let samplers=[new GPUBindGroupSampler(1,this.compare)];
        this.panelLight=new GPUBindGroup(this.panel.getBindGroupLayout(1),[],textures,samplers);
        this.environmentLight=new GPUBindGroup(this.environment.getBindGroupLayout(1),[],textures,samplers);
        this.floor=new Environment(this,0);this.plinth=new Environment(this,1);
    }
    bind(p:Sheet):void {
        if(p.bg!=null) p.bg!.release();
        if(p.shadowBg!=null) p.shadowBg!.release();
        let ubos=[new GPUBindGroupUBO(0,p.ubo)];
        let textures=[new GPUBindGroupTexture(1,p.canvas.image.view()!),new GPUBindGroupTexture(2,this.pattern.image.view()!)];
        let samplers=[new GPUBindGroupSampler(3,this.sampler)];
        p.bg=new GPUBindGroup(this.panel.getBindGroupLayout(0),ubos,textures,samplers);
        p.shadowBg=new GPUBindGroup(this.panelShadow.getBindGroupLayout(0),ubos,textures,samplers);
    }
    sheet(art:Artboard?,canvas:Canvas,w:f64,h:f64,kind:i32):Sheet {
        let p=new Sheet(art,canvas,w,h,kind);this.bind(p);return p;
    }
    place(p:Sheet,vp:Mat4,model:Mat4,bend:f64,t:f64,opacity:f64,travel:f64,a:Vector=Vector(),b:Vector=Vector()):void {
        p.model=model;Mat4.multiply(p.mvp,vp,model);p.bend=bend;
        vp.writeToBuffer(p.buf,0);model.writeToBuffer(p.buf,64);this.lightVP.writeToBuffer(p.buf,128);
        floats(p.buf,192,[p.w,p.h,bend,p.kind,t,opacity,travel,0,a.x,a.y,a.z,a.length(),b.x,b.y,b.z,0]);
        p.ubo.update(0,p.buf);
    }
    update(vp:Mat4,eye:Vector,unit:f64,cx:f64,top:f64,cz:f64,rx:f64,rz:f64,w:f64,h:f64):void {
        this.lightVP=Mat4.ortho(<f32>(-1300*unit),<f32>(1300*unit),<f32>(-1100*unit),<f32>(1100*unit),1,<f32>(6000*unit))*Mat4.lookAtVector(xyz(1300*unit,2700*unit,2300*unit),xyz(0,-60*unit,0),xyz(0,1,0));
        let objects=[this.floor,this.plinth];
        for(let i=0;i<objects.length;i++) {
            let p=objects[i];vp.writeToBuffer(p.buf,0);this.lightVP.writeToBuffer(p.buf,64);
            floats(p.buf,128,[eye.x,eye.y,eye.z,eye.length(),cx,top,cz,rx,rz,64*unit,p.kind,0,-290*unit,w,h,0]);p.ubo.update(0,p.buf);
        }
    }
    shadowSurface(p:Sheet,pass:GPURenderPass):void {pass.setPipeline(this.panelShadow);pass.setBindGroup(0,p.shadowBg!);pass.draw(128*192*6);}
    shadowPlinth(pass:GPURenderPass):void {pass.setPipeline(this.environmentShadow);pass.setBindGroup(0,this.plinth.shadowBg);pass.draw(128*33);}
    drawSurface(p:Sheet,pass:GPURenderPass):void {pass.setPipeline(this.panel);pass.setBindGroup(0,p.bg!);pass.setBindGroup(1,this.panelLight);pass.draw(128*192*6);}
    drawEnvironment(pass:GPURenderPass):void {
        pass.setPipeline(this.environment);pass.setBindGroup(1,this.environmentLight);
        pass.setBindGroup(0,this.floor.bg);pass.draw(6);pass.setBindGroup(0,this.plinth.bg);pass.draw(128*33);
    }
}
