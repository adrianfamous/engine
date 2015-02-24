mat3 environmentTransform;
float sine(float slow) { return (sin(time * slow) + 1.) / 2.; }
#define uScale -1.
#define vVertex vPosition
#define vMasking 1.
#define uPlaneN vec3(0, 0, -54)
#define uPlaneO vec3(-.55425626, 0, 0)
#define uIblTransform  mat4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, -54, 1)
#define uExposure .3
#define vAlbedo vec3(1, 1, 1) 
#define vRoughness glossiness
#define vMetallic metalness
vec4 getFragColor(const in vec3 frag) {
  vec3 col = frag * (0.3 + 0.7 * vMasking);
  if(uScale > 0.0 && abs(dot(uPlaneN, vVertex - uPlaneO)) < 0.15 / uScale)
      return vec4(min(col * 1.3, 1.0), 1.0);
  return vec4(col, 1.0);
}
vec4 getFragColor(const in vec4 frag) {
  vec3 col = frag.rgb * (0.3 + 0.7 * vMasking);
  if(uScale > 0.0 && abs(dot(uPlaneN, vVertex - uPlaneO)) < 0.15 / uScale)
      return vec4(min(col * 1.3, 1.0), 0.2);
  return vec4(col, frag.a);
}
#define PI 3.1415926535897932384626433832795
#define PI_2 (2.0*3.1415926535897932384626433832795)
#define INV_PI 1.0/PI
#define INV_LOG2 1.4426950408889634073599246810019
#define DefaultGamma 2.4
vec2 environmentSize = resolution.xy;
vec2 environmentLodRange = vec2(10, 5);
float linearrgb_to_srgb1(const in float c, const in float gamma) {
  float v = 0.0;
  if(c < 0.0031308) {
    if ( c > 0.0)
      v = c * 12.92;
  } else {
    v = 1.055 * pow(c, 1.0/ gamma) - 0.055;
  }
  return v;
}

vec4 linearTosRGB(const in vec4 col_from, const in float gamma) {
  vec4 col_to;
  col_to.r = linearrgb_to_srgb1(col_from.r, gamma);
  col_to.g = linearrgb_to_srgb1(col_from.g, gamma);
  col_to.b = linearrgb_to_srgb1(col_from.b, gamma);
  col_to.a = col_from.a;
  return col_to;
}

vec3 linearTosRGB(const in vec3 col_from, const in float gamma) {
  vec3 col_to;
  col_to.r = linearrgb_to_srgb1(col_from.r, gamma);
  col_to.g = linearrgb_to_srgb1(col_from.g, gamma);
  col_to.b = linearrgb_to_srgb1(col_from.b, gamma);
  return col_to;
}

float sRGBToLinear(const in float c, const in float gamma) {
  float v = 0.0;
  if ( c < 0.04045 ) {
    if ( c >= 0.0 )
      v = c * ( 1.0 / 12.92 );
  } else {
    v = pow( ( c + 0.055 ) * ( 1.0 / 1.055 ), gamma );
  }
  return v;
}
vec4 sRGBToLinear(const in vec4 col_from, const in float gamma) {
  vec4 col_to;
  col_to.r = sRGBToLinear(col_from.r, gamma);
  col_to.g = sRGBToLinear(col_from.g, gamma);
  col_to.b = sRGBToLinear(col_from.b, gamma);
  col_to.a = col_from.a;
  return col_to;
}
vec3 sRGBToLinear(const in vec3 col_from, const in float gamma) {
  vec3 col_to;
  col_to.r = sRGBToLinear(col_from.r, gamma);
  col_to.g = sRGBToLinear(col_from.g, gamma);
  col_to.b = sRGBToLinear(col_from.b, gamma);
  return col_to;
}

const mat3 LUVInverse = mat3( 6.0013, -2.700, -1.7995, -1.332, 3.1029, -5.7720, 0.3007, -1.088, 5.6268 );
vec3 LUVToRGB( const in vec4 vLogLuv ) {
  float Le = vLogLuv.z * 255.0 + vLogLuv.w;
  vec3 Xp_Y_XYZp;
  Xp_Y_XYZp.y = exp2((Le - 127.0) / 2.0);
  Xp_Y_XYZp.z = Xp_Y_XYZp.y / vLogLuv.y;
  Xp_Y_XYZp.x = vLogLuv.x * Xp_Y_XYZp.z;
  return max(LUVInverse * Xp_Y_XYZp, 0.0);
}

vec2 computeUVForMipmap( const in float level, const in vec2 uv, const in float size, const in float maxLOD ) {
  float widthForLevel = exp2( maxLOD - level);
  vec2 uvSpaceLocal =  vec2(1.0) + uv * vec2(widthForLevel - 2.0, widthForLevel * 0.5 - 2.0);
  uvSpaceLocal.y += size - widthForLevel;
  return uvSpaceLocal / size;
}

vec2 normalToPanoramaUVY( const in vec3 dir ) {
  float n = length(dir.xz);
  vec2 pos = vec2( (n>0.0000001) ? max(-1.0,dir.x / n) : 0.0, dir.y);
  if ( pos.x > 0.0 ) pos.x = min( 0.999999, pos.x );
  pos = acos(pos)*INV_PI;
  pos.x = (dir.z > 0.0) ? pos.x*0.5 : 1.0-(pos.x*0.5);
  pos.x = mod(pos.x-0.25+1.0, 1.0 );
  pos.y = 1.0-pos.y;
  return pos;
}

vec3 texturePanoramaLod(const in sampler2D texture, const in vec2 size , const in vec3 direction, const in float lodInput, const in float maxLOD ) {
  float lod = min( maxLOD, lodInput );
  vec2 uvBase = normalToPanoramaUVY( direction );
  vec3 texel0 = LUVToRGB(texture2D( texture, computeUVForMipmap(floor(lod), uvBase, size.x, maxLOD )));
  vec3 texel1 = LUVToRGB(texture2D( texture, computeUVForMipmap(ceil(lod), uvBase, size.x, maxLOD )));
  return mix(texel0, texel1, fract( lod ) );
}

vec3 integrateBRDFApprox(const in vec3 specular, float roughness, float NoV) {
  const vec4 c0 = vec4(-1, -0.0275, -0.572, 0.022);
  const vec4 c1 = vec4(1, 0.0425, 1.04, -0.04);
  vec4 r = roughness * c0 + c1;
  float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
  vec2 AB = vec2(-1.04, 1.04) * a004 + r.zw;
  return specular * AB.x + AB.y;
}

vec3 approximateSpecularIBL( const in vec3 specularColor, float rLinear, const in vec3 N, const in vec3 V ) {
  float NoV = clamp( dot( N, V ), 0.0, 1.0 );
  vec3 R = normalize( (2.0 * NoV ) * N - V);
  vec3 prefilteredColor = texturePanoramaLod( image, environmentSize, environmentTransform * R, rLinear * environmentLodRange[1], environmentLodRange[0] );
  return prefilteredColor * integrateBRDFApprox(specularColor, rLinear, NoV);
}

vec3 sph0 = vec3(0.23990666937971933, 0.22656132897048073, 0.24382270927912433);
vec3 sph1 = vec3(0.02277244385301296, 0.07715619985961389, 0.1724356440907309);
vec3 sph2 = vec3(0.02608399623768619, 0.025898669304921414, 0.026569813715271264);
vec3 sph3 = vec3(0.1321752857124422, 0.12603794956042963, 0.11169990884863842);
vec3 sph4 = vec3(-0.05930221775442135, -0.02676011647502097, 0.00796566135260379);
vec3 sph5 = vec3(-0.006821490008666235, -0.0021131962489668935, 0.002244323911606555);
vec3 sph6 = vec3(-0.04824954782702628, -0.04224386164148779, -0.04050826185790317);
vec3 sph7 = vec3(0.07057130854176336, 0.06650123787327868, 0.061894944435059406);
vec3 sph8 = vec3(0.11603028215152471, 0.08130308401094016, 0.0375649834342044);
vec3 sphericalHarmonics( const in vec3 normal ) {
  float x = normal.x;
  float y = normal.y;
  float z = normal.z;
  vec3 result = sph0 + sph1 * y + sph2 * z + sph3 * x + sph4 * y * x + sph5 * y * z + sph6 * (3.0 * z * z - 1.0) + sph7 * (z * x) + sph8 * (x*x - y*y);
  return max(result, vec3(0.0));
}

vec3 computeIBL_UE4( const in vec3 normal, const in vec3 view, const in vec3 albedo, const in float roughness, const in vec3 specular) {
  vec3 color = vec3(0);,
  if ( albedo != color )
    color += albedo * sphericalHarmonics( environmentTransform * normal );, 
  color += approximateSpecularIBL(specular, roughness, normal, view);
  return color;
}

mat3 getEnvironmentTransform( const in mat4 transform ) {
  vec3 x = vec3(transform[0][0], transform[1][0], transform[2][0]);
  vec3 y = vec3(transform[0][1], transform[1][1], transform[2][1]);
  vec3 z = vec3(transform[0][2], transform[1][2], transform[2][2]);
  return mat3(x, y, z);
}
vec3 applyLight(vec3 baseColor, vec3 _normal, float metalness, float f) {
  vec3 normal = 2. * (1. - vNormal);
  vec3 eye = vec3(0,0,-1);
  environmentTransform = getEnvironmentTransform( uIblTransform );
  float roughness = max( 0.0001, vRoughness );
  vec3 albedo = vAlbedo * (1.0 - vMetallic);
  vec3 specular = mix( vec3(0.04), vAlbedo, vMetallic);
  vec3 color = uExposure * computeIBL_UE4( normal, -eye, albedo, roughness, specular );
  return getFragColor( linearTosRGB(color, DefaultGamma )).rgb;
}
//float_definitions
float applyMaterial(float ID) {
  //float_applications
  return 1.;
}
//vec_definitions
vec3 applyMaterial(vec3 ID) {
  //vec_applications
  return vec3(1);
}
void main() {
    gl_FragColor.rgb = applyLight(
    baseColor.x >= 0. ? baseColor : applyMaterial(baseColor),
    normal.x >= 0. ? vNormal : (vNormal + applyMaterial(normal)),
    metalness >= 0. ? metalness: applyMaterial(metalness),
    glossiness >= 0. ? glossiness: applyMaterial(glossiness));
    gl_FragColor.a = opacity;
}
