import { GPUTexture, GPUTextureDesc, GPUPipeline, GPUPipelineDesc, GPUShaderModule, GPUDepthStencilDesc, GPUColorTargetDesc, GPUBlendState, GPUVertexBufferLayout, GPUSampler } from "rive/gpu";
import { TextureFormat, CompareFunction, BlendFactor, Filter, WrapMode } from "rive/gpu_enums";

export function texture(w: u32, h: u32, format: TextureFormat, samples: u32=1): GPUTexture {
    let d=new GPUTextureDesc(); d.width=w; d.height=h; d.format=format; d.renderTarget=true; d.sampleCount=samples;
    return new GPUTexture(d);
}
export function sampler(repeat: bool=false, compare: bool=false): GPUSampler {
    let wrap=repeat ? WrapMode.repeat : WrapMode.clampToEdge;
    return new GPUSampler(Filter.linear,Filter.linear,Filter.linear,wrap,wrap,
        compare ? CompareFunction.lessEqual : CompareFunction.none,compare ? 1 : 8);
}
export function makePipeline(shader: GPUShaderModule, shadow: bool=false, blend: bool=false,
    layout: GPUVertexBufferLayout[] = [], format: TextureFormat=TextureFormat.rgba8unorm,
    background: bool=false): GPUPipeline {
    let d=new GPUPipelineDesc(); d.vertexModule=shader; d.vertexEntryPoint=shadow ? "shadowVS" : "vs";
    d.vertexBuffers=layout; d.sampleCount=shadow ? 1 : 4;
    let depth=new GPUDepthStencilDesc(); depth.format=TextureFormat.depth32float;
    depth.compare=background ? CompareFunction.always : (blend ? CompareFunction.lessEqual : CompareFunction.less);
    depth.write=!background;
    if (shadow) { depth.depthBias=2; depth.depthBiasSlopeScale=2; }
    d.depthStencil=depth;
    if (!shadow) {
        d.fragmentModule=shader; d.fragmentEntryPoint="fs";
        let color=new GPUColorTargetDesc(); color.format=format;
        if (blend) { let b=new GPUBlendState(); b.dstColor=BlendFactor.oneMinusSrcAlpha; b.dstAlpha=BlendFactor.oneMinusSrcAlpha; color.blend=b; }
        d.colorTargets=[color];
    }
    return new GPUPipeline(d);
}
