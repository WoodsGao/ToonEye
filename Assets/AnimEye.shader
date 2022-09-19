Shader "Eye/AnimEye"
{
    Properties
    {
        _Albedo ("Albedo", 2D) = "white" {}
        _AmbientColor ("Ambient Color", Color) = (1,1,1,1)
        _Ambient ("Ambient", Range(0,10)) = 0.0
        _Specular ("Specular", Range(0,10)) = 0.0
        _SpecularColor1 ("SpecularColor1", Color) = (1,1,1,1)
        _SpecularColor2 ("SpecularColor2", Color) = (1,1,1,1)
        _SpMask ("Specular Mask", 2D) = "white" {}
        _HDR ("HDR", Cube) = "white" {}
        _HDRRotation ("HDR Rotation", Vector) = (0,0,0,0)
        _ScleraRange ("ScleraRange", Vector) = (0,0,0,0)
        
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
        _RefractColor ("RefractColor", Color) = (1,1,1,1)
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _Exposure ("Exposure", Range(0,1)) = 0.0
        _HeightScale ("HeightScale", Vector) = (0,0,0,0)
        _Refraction ("Refraction", Vector) = (0,0,0,0)
        _IrisFactor ("IrisFactor", Vector) = (0,0,0,0)
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
            #include "ToonEye.cginc"

            float4 _AmbientColor, _ScleraRange, _SpecularColor1, _SpecularColor2, _HDRRotation;
            float _Specular, _Ambient;
            sampler2D _Albedo, _SpMask;
            samplerCUBE _HDR;

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 worldPos: TEXCOORD2;
            };

            v2f vert (appdata_full v)
            {
                v2f o;
                float3 faceDir = normalize(mul(unity_ObjectToWorld, float4(0,0,1,0)).xyz);
                float scleraHeight = smoothstep(_ScleraRange.x, 1, -v.vertex.z * 100 * 0.5 + 0.5);
                v.vertex.z += scleraHeight * _ScleraRange.y * 0.01;
                v.normal = normalize(v.normal);
                v.normal = normalize(lerp(v.normal , -reflect(v.normal, faceDir), scleraHeight * _ScleraRange.z));
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = float2(cos(v.texcoord.x*PI*2), sin(v.texcoord.x*PI*2)) * v.texcoord.y * 2.0 + 0.5;
                o.uv = (o.uv-0.5)*_ScleraRange.w+0.5;
                // o.uv = v.texcoord;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos.xyz = mul(UNITY_MATRIX_M, float4(v.vertex.xyz, 1.0)).xyz;
                o.worldPos.w = scleraHeight;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normalDir = i.normal;
                // return float4(normalDir*0.5+0.5, 1);

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                // 模拟角膜-虹膜折射
                float3 faceDir = normalize(mul(unity_ObjectToWorld, float4(0,0,1,0)).xyz);
                float height = i.worldPos.w;
                // float height = GetHeightFromUV(i.uv);
                // float3 refractDir = normalize(lerp(viewDir, -normal, _Refraction.x));
                // float refractLength = pow(height, _Refraction.z) / dot(faceDir, refractDir);
                // float3 refractPath = refractDir * refractLength * _Refraction.y * 0.1;
                // // TODO: convert to local space
                // float2 refractUV = i.uv + float2(refractPath.x, -refractPath.y);
                // float innerHeight = GetHeightFromUV(refractUV);

                float3 albedo = tex2D(_Albedo, i.uv);
                float lumin = Luminance(albedo);
                float specular = tex2D(_SpMask, i.uv).r;
                // return float4(specular,0,0,1);
                // float3 iblDir = mul(GetRotationFromEuler(_HDRRotation.xyz), reflect(viewDir, normalDir));
                // float3 specularLight = texCUBElod(_HDR, float4(iblDir, 3))+0.2;
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 halfDir = normalize(viewDir+lightDir);

                float3 specularLight = _LightColor0.rgb * pow(saturate(dot(halfDir, normalDir)), 5);
                specularLight = max(0.2, specularLight);

                float3 specularColor = specularLight * specular * lumin * _Specular;
                float spHueFactor = pow(saturate(dot(viewDir, normalDir)), 5);

                specularColor *= lerp(_SpecularColor1.rgb, _SpecularColor2.rgb, spHueFactor);

                float3 ambientColor = _AmbientColor.rgb * _Ambient * albedo;

                float4 color = float4(specularColor + ambientColor,1);
                return color;
                // float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                // float3 lightColor = _LightColor0.rgb;
                // float3 reflectDir = normalize(reflect(-viewDir, normal));
                // float3 specular = lightColor*saturate(max(0.2, dot(lightDir, -reflectDir)));
                // // 虹膜边缘衰减
                // specular *= smoothstep(_IrisFactor.x, _IrisFactor.y, height);
                // // 瞳孔反光衰减
                // specular *= (1-smoothstep(_IrisFactor.z, _IrisFactor.w, height));
                // float4 color = float4(_Ambient.rgb*albedo+specular, 1);
                // color.rgb *= pow(_RefractColor.rgb, _RefractColor.a * refractLength);
                // // 折射透色效果
                // // return float4((refractLength-0.7)/0.3, 0,0,1);
                // // return float4(refractLength,0,0,1);
                // // return float4(lerp(float3(0.54,0.85,1)*0.5, color.xyz, refractLength),1);
                // // 巩膜虹膜衔接
                // color =lerp(float4(0.8,0.76,0.79,1), color, smoothstep(_ScleraRange.x, _ScleraRange.y, innerHeight));
                // // 角膜反光
                // float2 longDir = normalize(reflectDir.xz);
                // float long = acos(longDir.x) * (step(0, longDir.y)*2-1);
                // float lat = asin(reflectDir.y);
                // float3 reflectColor = tex2Dlod(_HDR, float4(TRANSFORM_TEX(float2(long*0.5/PI+0.5, lat/PI+0.5), _HDR), 0,2)).rgb;
                // float fresnel = saturate(_Metallic + (1- _Metallic) * pow(1 - saturate(dot(normal, -viewDir)), 5));
                // color.rgb = fresnel * pow(reflectColor,0.5) + color.rgb;
                // return color;
            }

            ENDCG
        }

        GrabPass
        {
            "_GrabTexture"
        }

        // 角膜反射折射
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma multi_compile_fog
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityPBSLighting.cginc"
            #include "ToonEye.cginc"

            float4 _Refraction, _ScleraRange;
            float _Specular, _Ambient;
            sampler2D _GrabTexture;
            samplerCUBE _HDR;

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 worldPos: TEXCOORD2;
                float2 screenPos: TEXCOORD3;
            };

            v2f vert (appdata_full v)
            {
                v2f o;
                float scleraHeight = smoothstep(_ScleraRange.x, 1, -v.vertex.z * 100 * 0.5 + 0.5);
                v.normal = normalize(v.normal);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = float2(cos(v.texcoord.x*PI*2), sin(v.texcoord.x*PI*2)) * v.texcoord.y * 2.0 + 0.5;
                o.uv = (o.uv-0.5)*_ScleraRange.w+0.5;
                // o.uv = v.texcoord;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos.xyz = mul(UNITY_MATRIX_M, float4(v.vertex.xyz, 1.0)).xyz;
                o.worldPos.w = scleraHeight;
                o.screenPos = o.pos.xy / o.pos.w * 0.5 + 0.5;
                o.screenPos.y = 1-o.screenPos.y;
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normalDir = i.normal;
                float2 screenPos = i.screenPos;

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                // 模拟角膜-虹膜折射
                float3 faceDir = normalize(mul(unity_ObjectToWorld, float4(0,0,1,0)).xyz);
                float height = i.worldPos.w;
                float3 refractDir = normalize(lerp(viewDir, normalDir, _Refraction.x));
                float refractLength = height / dot(faceDir, refractDir);
                float3 refractPath = refractDir * refractLength * _Refraction.y * 0.1;
                // // TODO: convert to local space
                screenPos += float2(refractPath.x, -refractPath.y);
                return tex2D(_GrabTexture, screenPos);
                // float innerHeight = GetHeightFromUV(refractUV);

                // float3 albedo = tex2D(_Albedo, i.uv);
                // float lumin = Luminance(albedo);
                // float specular = tex2D(_SpMask, i.uv).r;
                // return float4(specular,0,0,1);
                // float3 iblDir = mul(GetRotationFromEuler(_HDRRotation.xyz), reflect(viewDir, normalDir));
                // float3 specularLight = texCUBElod(_HDR, float4(iblDir, 3))+0.2;
                // float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                // float3 halfDir = normalize(viewDir+lightDir);

                // float3 specularLight = _LightColor0.rgb * pow(saturate(dot(halfDir, normalDir)), 5);
                // specularLight = max(0.2, specularLight);

                // float3 specularColor = specularLight * specular * lumin * _Specular;
                // float spHueFactor = pow(saturate(dot(viewDir, normalDir)), 5);

                // specularColor *= lerp(_SpecularColor1.rgb, _SpecularColor2.rgb, spHueFactor);

                // float3 ambientColor = _AmbientColor.rgb * _Ambient * albedo;

                // float4 color = float4(specularColor + ambientColor,1);
                // return color;
                // float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                // float3 lightColor = _LightColor0.rgb;
                // float3 reflectDir = normalize(reflect(-viewDir, normal));
                // float3 specular = lightColor*saturate(max(0.2, dot(lightDir, -reflectDir)));
                // // 虹膜边缘衰减
                // specular *= smoothstep(_IrisFactor.x, _IrisFactor.y, height);
                // // 瞳孔反光衰减
                // specular *= (1-smoothstep(_IrisFactor.z, _IrisFactor.w, height));
                // float4 color = float4(_Ambient.rgb*albedo+specular, 1);
                // color.rgb *= pow(_RefractColor.rgb, _RefractColor.a * refractLength);
                // // 折射透色效果
                // // return float4((refractLength-0.7)/0.3, 0,0,1);
                // // return float4(refractLength,0,0,1);
                // // return float4(lerp(float3(0.54,0.85,1)*0.5, color.xyz, refractLength),1);
                // // 巩膜虹膜衔接
                // color =lerp(float4(0.8,0.76,0.79,1), color, smoothstep(_ScleraRange.x, _ScleraRange.y, innerHeight));
                // // 角膜反光
                // float2 longDir = normalize(reflectDir.xz);
                // float long = acos(longDir.x) * (step(0, longDir.y)*2-1);
                // float lat = asin(reflectDir.y);
                // float3 reflectColor = tex2Dlod(_HDR, float4(TRANSFORM_TEX(float2(long*0.5/PI+0.5, lat/PI+0.5), _HDR), 0,2)).rgb;
                // float fresnel = saturate(_Metallic + (1- _Metallic) * pow(1 - saturate(dot(normal, -viewDir)), 5));
                // color.rgb = fresnel * pow(reflectColor,0.5) + color.rgb;
                // return color;
            }

            ENDCG
        }
    }
}
