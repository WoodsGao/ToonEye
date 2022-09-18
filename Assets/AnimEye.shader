Shader "Eye/AnimEye"
{
    Properties
    {
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
        _Ambient ("Ambient", Color) = (1,1,1,1)
        _RefractColor ("RefractColor", Color) = (1,1,1,1)
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _Exposure ("Exposure", Range(0,1)) = 0.0
        _HeightScale ("HeightScale", Vector) = (0,0,0,0)
        _ScleraRange ("ScleraRange", Vector) = (0,0,0,0)
        _Refraction ("Refraction", Vector) = (0,0,0,0)
        _IrisFactor ("IrisFactor", Vector) = (0,0,0,0)
        _ReflectionHDR ("Reflection HDR", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        Pass
        {
            CGPROGRAM
            #pragma multi_compile_fog
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityPBSLighting.cginc"

            #define PI 3.1415926535898

            float4 _Refraction, _IrisFactor, _ReflectionHDR_ST, _Ambient, _ScleraRange, _HeightScale, _RefractColor;
            float _Smoothness, _Metallic, _Exposure;
            sampler2D _ReflectionHDR;

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 tangent : TEXCOORD2;
                float3 bitangent : TEXCOORD3;
                float3 worldPos: TEXCOORD4;
                SHADOW_COORDS(5)
            };

            v2f vert (appdata_full v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = float2(cos(v.texcoord.x*PI*2), sin(v.texcoord.x*PI*2)) * v.texcoord.y * 2.0 + 0.5;
                // o.uv = v.texcoord;
                o.normal = UnityObjectToWorldNormal(v.normal);	
                o.tangent = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.bitangent = normalize(cross(o.normal, o.tangent) * v.tangent.w);
                o.worldPos = mul(UNITY_MATRIX_M, float4(v.vertex.xyz, 1.0)).xyz;
                TRANSFER_SHADOW(o);

                return o;
            }

            float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
            {
                return F0 + (max(float3(1 ,1, 1) * (1 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
            }

            float GetHeightFromUV(float2 uv)
            {
                float radius = saturate(length(uv-0.5)*_HeightScale.x+_HeightScale.y);
                return 1-radius * radius;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = i.normal;

                float3 viewDir = normalize(i.worldPos - _WorldSpaceCameraPos.xyz);
                // 模拟角膜-虹膜折射
                float3 faceDir = normalize(mul(unity_ObjectToWorld, float4(0,0,1,0)).xyz);
                float height = GetHeightFromUV(i.uv);
                float3 refractDir = normalize(lerp(viewDir, -normal, _Refraction.x));
                float refractLength = pow(height, _Refraction.z) / dot(faceDir, refractDir);
                float3 refractPath = refractDir * refractLength * _Refraction.y * 0.1;
                // TODO: convert to local space
                float2 refractUV = i.uv + float2(refractPath.x, -refractPath.y);
                float innerHeight = GetHeightFromUV(refractUV);

                float3 albedo = float3(0.54,0.85,1);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 lightColor = _LightColor0.rgb;
                float3 reflectDir = normalize(reflect(-viewDir, normal));
                float3 specular = lightColor*saturate(max(0.2, dot(lightDir, -reflectDir)));
                // 虹膜边缘衰减
                specular *= smoothstep(_IrisFactor.x, _IrisFactor.y, innerHeight);
                // 瞳孔反光衰减
                specular *= (1-smoothstep(_IrisFactor.z, _IrisFactor.w, innerHeight));
                float4 color = float4(_Ambient.rgb*albedo+specular, 1);
                color.rgb *= pow(_RefractColor.rgb, _RefractColor.a * refractLength);
                // 折射透色效果
                // return float4((refractLength-0.7)/0.3, 0,0,1);
                // return float4(refractLength,0,0,1);
                // return float4(lerp(float3(0.54,0.85,1)*0.5, color.xyz, refractLength),1);
                // 巩膜虹膜衔接
                color =lerp(float4(0.8,0.76,0.79,1), color, smoothstep(_ScleraRange.x, _ScleraRange.y, innerHeight));
                // 角膜反光
                float2 longDir = normalize(reflectDir.xz);
                float long = acos(longDir.x) * (step(0, longDir.y)*2-1);
                float lat = asin(reflectDir.y);
                float3 reflectColor = tex2Dlod(_ReflectionHDR, float4(TRANSFORM_TEX(float2(long*0.5/PI+0.5, lat/PI+0.5), _ReflectionHDR), 0,2)).rgb;
                float fresnel = saturate(_Metallic + (1- _Metallic) * pow(1 - saturate(dot(normal, -viewDir)), 5));
                color.rgb = fresnel * pow(reflectColor,0.5) + color.rgb;
                return color;
            }

            ENDCG
        }
    }
}
