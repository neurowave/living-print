import { Context } from "rive/host";
import { Canvas } from "rive/canvas";
import { Mat4 } from "rive/mat4";
import { Vector } from "rive/vector";
import { Buffer } from "rive/buffer";
import { Image, ImageSampler } from "rive/image";
import { BlendMode } from "rive/paint";
import { GPUBuffer, GPUBindGroup, GPUBindGroupUBO, GPUBindGroupTexture, GPUBindGroupSampler, GPUPipeline, GPURenderPass, GPUVertexBufferLayout, GPUVertexAttribute } from "rive/gpu";
import { BufferUsage, VertexFormat, IndexFormat } from "rive/gpu_enums";
import { Stage } from "./stage";
import { sampler, makePipeline } from "./gpu_helpers";
import { xyz, floats } from "./support";

export class Shoe {
    ground:Vector[]=[]; images:Image[]=[]; canvases:Canvas[]=[];
    pipeline:GPUPipeline;shadow:GPUPipeline;
    ubo:GPUBuffer=new GPUBuffer(BufferUsage.uniform,256);buf:ArrayBuffer=new ArrayBuffer(256);
    vertices:GPUBuffer;indices:GPUBuffer;uniform:GPUBindGroup;shadowBg:GPUBindGroup;texture:GPUBindGroup;
    textureReady:bool=false;
    constructor(context:Context,pattern:Canvas,mark:Canvas,stage:Stage) {
        let shader=context.shader("footwear")!,vertices=context.blob("shoeVertices")!,indices=context.blob("shoeIndices")!;
        let layout=new GPUVertexBufferLayout();layout.stride=36;
        layout.attributes=[new GPUVertexAttribute(VertexFormat.float3,0,0),new GPUVertexAttribute(VertexFormat.float3,1,12),new GPUVertexAttribute(VertexFormat.float2,2,24),new GPUVertexAttribute(VertexFormat.float1,3,32)];
        this.pipeline=makePipeline(shader,false,false,[layout]);this.shadow=makePipeline(shader,true,false,[layout]);
        for(let i=10331;i<=11696;i+=6) {let o=i*36;this.ground.push(xyz(Buffer.readf32(vertices,o),Buffer.readf32(vertices,o+4),Buffer.readf32(vertices,o+8)));}
        let names=["shoeColor","shoeNormal","shoeOrm"],textures:GPUBindGroupTexture[]=[];
        for(let i=0;i<names.length;i++) {
            let im=context.image(names[i])!,can=context.canvas(im.width,im.height)!;
            this.images.push(im);this.canvases.push(can);textures.push(new GPUBindGroupTexture(i,can.image.view()!));
        }
        textures.push(new GPUBindGroupTexture(3,pattern.image.view()!));textures.push(new GPUBindGroupTexture(4,mark.image.view()!));textures.push(new GPUBindGroupTexture(6,stage.shadowView));
        this.vertices=new GPUBuffer(BufferUsage.vertex,vertices.byteLength,vertices,true);this.indices=new GPUBuffer(BufferUsage.index,indices.byteLength,indices,true);
        let ubos=[new GPUBindGroupUBO(0,this.ubo)],depth=[new GPUBindGroupTexture(1,stage.shadowView)];
        this.uniform=new GPUBindGroup(this.pipeline.getBindGroupLayout(0),ubos,depth);this.shadowBg=new GPUBindGroup(this.shadow.getBindGroupLayout(0),ubos,[new GPUBindGroupTexture(1,stage.standInView)]);
        this.texture=new GPUBindGroup(this.pipeline.getBindGroupLayout(1),[],textures,[new GPUBindGroupSampler(5,sampler(true)),new GPUBindGroupSampler(7,stage.compare)]);
    }
    update(vp:Mat4,model:Mat4,eye:Vector,scale:f64,stage:Stage,palette:i32[],reveal:f64):void {
        if(!this.textureReady) {
            for(let i=0;i<this.canvases.length;i++) {let can=this.canvases[i],r=can.beginFrame()!;r.drawImage(this.images[i],ImageSampler(),BlendMode.srcOver,1);can.endFrame();}
            this.textureReady=true;
        }
        vp.writeToBuffer(this.buf,0);model.writeToBuffer(this.buf,64);stage.lightVP.writeToBuffer(this.buf,128);
        floats(this.buf,192,[eye.x,eye.y,eye.z,0,scale,reveal,0,0,palette[6]/255.0,palette[7]/255.0,palette[8]/255.0,1,palette[0]/255.0,palette[1]/255.0,palette[2]/255.0,1]);this.ubo.update(0,this.buf);
    }
    bottom(m:Mat4):f64 {let y:f64=Infinity;for(let i=0;i<this.ground.length;i++){let p=this.ground[i];y=Math.min(y,m.transformPoint(p.x,p.y,p.z).y);}return y;}
    draw(pass:GPURenderPass,shadow:bool=false):void {
        pass.setPipeline(shadow?this.shadow:this.pipeline);pass.setBindGroup(0,shadow?this.shadowBg:this.uniform);if(!shadow)pass.setBindGroup(1,this.texture);
        pass.setVertexBuffer(0,this.vertices);pass.setIndexBuffer(this.indices,IndexFormat.uint32);pass.drawIndexed(68100);
    }
}
