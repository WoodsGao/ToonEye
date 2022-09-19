Shader "Eye/ToonEye"
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
                // discard;
                float3 normalDir = i.normal;
                // return float4(normalDir*0.5+0.5, 1);

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                // 模拟角膜-虹膜折射
                float3 faceDir = normalize(mul(unity_ObjectToWorld, float4(0,0,1,0)).xyz);
                float height = i.worldPos.w;
                float isSclera = step(0.01, height);

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

                float3 ambientColor = lerp(float3(1,1,1), _AmbientColor.rgb * _Ambient, isSclera) * albedo;

                float4 color = float4(specularColor + ambientColor,1);
                return color;
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

            float4 _Refraction, _ScleraRange, _HDRRotation, _RefractColor;
            float _Specular, _Ambient, _Metallic;
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
                // discard;
                float3 normalDir = i.normal;
                // float2 screenPos = i.screenPos;

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                // 模拟角膜-虹膜折射
                float3 faceDir = normalize(mul(unity_ObjectToWorld, float4(0,0,1,0)).xyz);
                float height = i.worldPos.w;
                float isSclera = step(0.01, height);

                float3 refractDir = normalize(lerp(viewDir, normalDir, _Refraction.x));
                // return float4(refractDir, 1);
                float refractLength = dot(height*faceDir, refractDir);
                float3 refractPos = i.worldPos.xyz + refractDir * refractLength * _Refraction.y * 0.1;
                float4 refractPosCS = mul(UNITY_MATRIX_VP, float4(refractPos, 1));

                float2 screenPos = float2(refractPosCS.x, -refractPosCS.y) / refractPosCS.w * 0.5 + 0.5;
                screenPos = lerp(i.screenPos, screenPos, step(0.2, height));
                float3 refractColor = tex2D(_GrabTexture, screenPos);
                refractColor *= lerp(1, pow(_RefractColor.a, abs(refractLength) + _Refraction.z), isSclera);
                refractColor += lerp(1, pow(_RefractColor.rgb, abs(refractLength) + _Refraction.z), isSclera);

                float3 iblDir = mul(GetRotationFromEuler(_HDRRotation.xyz), reflect(viewDir, normalDir));
                float3 reflectColor = texCUBElod(_HDR, float4(iblDir, 2));
                float metallic = lerp(0.2, 1, isSclera) * _Metallic;
                float fresnel = saturate(metallic + (1- metallic) * pow(1 - saturate(dot(normalDir, viewDir)), 5));
                
                float4 color = float4(fresnel * reflectColor + refractColor, 1);
                color.a = smoothstep(0,0.1,height);
                return color;
            }

            ENDCG
        }
    }
}
