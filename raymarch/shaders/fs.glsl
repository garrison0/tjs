#define AA 2 //# of anti-aliasing passes

varying vec2 vUv;
uniform vec2 uResolution;
uniform float uTime;

// noise stuff
float random (in vec2 st) {
    return fract(sin(dot(st.xy,
                            vec2(12.9898,78.233)))*
        43758.5453123);
}

float noise (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

#define OCTAVES 6
float fbm (in vec2 st) {
    // Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    //
    // Loop of octaves
    for (int i = 0; i < OCTAVES; i++) {
        value += amplitude * noise(st);
        st *= 2.;
        amplitude *= .5;
    }
    return value;
}

// --------- DISTANCE FUNCTIONS ---------- //
float sdfSphere(vec3 p, float r) {
    return length( p ) - r;
}

float sdTorus( vec3 p, vec2 t )
{
    vec2 q = vec2(length(p.xz)-t.x,p.y);
    return length(q)-t.y;
}

float sdRoundBox( vec3 p, vec3 b, float r )
{
    vec3 q = abs(p) - b;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

// --------------- RENDERING FUNCTIONS ------------- // 

// ---- UTILITIES --- // 
vec3 rotatePoint(vec3 p, vec3 n, float theta) { 
    vec4 q = vec4(cos(theta / 2.0), sin (theta / 2.0) * n);
    vec3 temp = cross(q.xyz, p) + q.w * p;
    vec3 rotated = p + 2.0*cross(q.xyz, temp);
    return rotated;
}

// ------ MAPPING / LIGHTING ----- // 
vec2 opU( vec2 d1, vec2 d2 )
{
	return (d1.x<d2.x) ? d1 : d2;
}

vec2 opSmoothU( vec2 d1, vec2 d2, float k) 
{ 
    float h = max( k - abs(d1.x - d2.x), 0.0) / k;
    float k2 = 10.0 + k;
    float h2 = max( k2- abs(d1.y - d2.y), 0.0) / k2;
    float diff = h*h*h*k*(1.0/6.0);
    float diff2 = h2*h2*h2*k2*(1.0/6.0);
    return vec2( min(d1.x, d2.x) - diff,
                 (d1.y + d2.y) / 2.0);
}

vec2 map (vec3 p) { 
    vec2 res = vec2(1e10, 0.0);

    // move the primitives around
    p = p - vec3(0,2.0,0);

    // twist the space
    // const float k = 0.7; // or some other amount
    // float c = cos(k*p.y);
    // float s = sin(k*p.y);
    // mat2  m = mat2(c,-s,s,c);
    // vec3  q = vec3(m*p.xz,p.y);

    // repeat
    // bunch of metaballs in a bowditch curve
    float rad = 2.5;
    for (int i = 1; i<4; i++) { 
        float t = 60.;
        float iTime = t + 0.01 * uTime;
        vec3 trans = rad * vec3(sin(4. * iTime + t + 3.14159 / 2.0),
                                sin(5. * iTime + t),
                                sin(iTime / 4.0 + t));
        float jTime = uTime * 0.1;
        vec3 c = vec3(2.0 * (1.+sin(jTime * 0.2)) * 0.9, 2.0 * (1.+sin(jTime))* 0.5, 2.0 * (1.+cos(jTime)*0.5));
        vec3 d = p + trans;
        vec3 q = mod( d + 0.5 * c, c) - 0.5 * c;

        res = opSmoothU( vec2(sdfSphere(q, 0.03), 20.5), res, 0.6 );
     }

    return res;
}

vec3 calcNormal( in vec3 p )
{
    const float eps = 0.0001; 
    const vec2 h = vec2(eps,0);
    return normalize( vec3(map(p+h.xyy).x - map(p-h.xyy).x,
                        map(p+h.yxy).x - map(p-h.yxy).x,
                        map(p+h.yyx).x - map(p-h.yyx).x ) );
}

float calcAO( in vec3 pos, in vec3 nor )
{
	float occ = 0.0;
    float sca = 1.0;
    for( int i=0; i<5; i++ )
    {
        float h = 0.01 + 0.12*float(i)/4.0;
        float d = map( pos + h*nor ).x;
        occ += (h-d)*sca;
        sca *= 0.95;
        if( occ>0.35 ) break;
    }
    return clamp( 1.0 - 3.0*occ, 0.0, 1.0 ) * (0.5+0.5*nor.y);
}

float calcSoftshadow( in vec3 ro, in vec3 rd, float mint, float maxt, float k )
{
    float res = 1.0;
    for( float t=mint; t<maxt; )
    {
        float h = map(ro + rd*t).x;
        if( h<0.001 )
            return 0.0;
        res = min( res, k*h/t );
        t += h;
    }
    return res;
}

vec2 raycast (in vec3 ro, in vec3 rd){
    vec2 res = vec2(-1.0,-1.0);

    float tmin = 0.1;
    float tmax = 100.0;
    
    // raytrace floor plane
    float tp1 = (-1.0-ro.y)/rd.y;
    if( tp1 > -1.0 )
    {
        tmax = min( tmax, tp1 );
        res = vec2( tp1, 1.0 );
    }

    // raycast the primitives
    float eps = 0.0001;
    float t = tmin;
    for( int i = 0; i < 70 && t < tmax; i++) {
        vec2 h = map( ro + rd*t );

        if( abs(h.x) < eps){
            res = vec2(t, h.y);
            break;
        } 

        t += h.x;
    }

    return res;
}

vec3 render(in vec3 ro, in vec3 rd, in vec3 rdx, in vec3 rdy) { 
    // background - will probably be overwritten
    vec3 col = vec3(0.4,0.4,0.7) - max(rd.y, 0.0) * 0.3;

    vec2 res = raycast(ro,rd);
    float t = res.x;
    float m = res.y;

    // i.e., if given some float to make color with
    if (m > -0.5) { 
        vec3 pos = ro + rd*t;
        vec3 nor = (m<1.5) ? vec3(0.0,1.0,0.0) : calcNormal(pos);
        vec3 ref = reflect( rd, nor );
    
        //col = vec3(t);

        col = 0.15 + 0.15 * sin (m * 2.0 + vec3(0.,1.,2.));
        float ks = 1.0;

        // could add whatever for the floor

        float occ = calcAO( pos, nor );
        
        vec3 lin = vec3(0.0);
        // sun 
        {
            vec3  lig = normalize( vec3(-0.5, 1.1, -0.6) );
            vec3  hal = normalize( lig-rd );
            float dif = clamp( dot( nor, lig ), 0.0, 1.0 );
        	      dif *= calcSoftshadow( pos, lig, 0.02, 2.5, 16.0 );
			float spe = pow( clamp( dot( nor, hal ), 0.0, 1.0 ),16.0);
                  spe *= dif;
                  spe *= 0.04+0.96*pow(clamp(1.0-dot(hal,lig),0.0,1.0),5.0);
            lin += col*2.20*dif*vec3(1.30,1.00,0.70);
            lin +=     5.00*spe*vec3(1.30,1.00,0.70)*ks;
        }
        // sky / reflections
        {
            float dif = sqrt(clamp( 0.5+0.5*nor.y, 0.0, 1.0 ));
                  dif *= occ;
            float spe = smoothstep( -0.2, 0.2, ref.y );
                  spe *= dif;
                  spe *= 0.04+0.96*pow(clamp(1.0+dot(nor,rd),0.0,1.0), 5.0 );
                  spe *= calcSoftshadow( pos, ref, 0.02, 2.5, 16.0 );
            lin += col*0.60*dif*vec3(0.40,0.60,1.15);
            lin +=     1.25*spe*vec3(0.40,0.60,1.30)*ks;
        }
        // back
        {
        	float dif = clamp( dot( nor, normalize(vec3(0.5,0.0,0.6))), 0.0, 1.0 )*clamp( 1.0-pos.y,0.0,1.0);
                  dif *= occ;
        	lin += col*0.55*dif*vec3(0.25,0.25,0.25);
        }
        // sss
        {
            float dif = pow(clamp(1.0+dot(nor,rd),0.0,1.0),2.0);
                  dif *= occ;
        	lin += col*0.25*dif*vec3(1.00,1.00,1.00);
        }

        col = lin;

        col = mix( col, vec3(0.6,0.6,0.9), 1.0-exp( -0.0001*t*t*t ) );
    }

    return vec3( clamp(col, 0.0, 1.0) );
}

mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
    vec3 cw = normalize(ta-ro);
    vec3 cp = vec3(sin(cr), cos(cr),0.0);
    vec3 cu = normalize( cross(cw,cp) );
    vec3 cv =          ( cross(cu,cw) );
    return mat3( cu, cv, cw );
}

void main() {
    // camera
    vec3 ta = vec3( 0, 0, -2.0);
    vec3 ro = vec3(-1.0, 7.55, 10.5);
    // vec3 ro = vec3( 12.25 * cos (0.25 * uTime), 10.0, 12.25 * sin (0.25 * uTime));
    mat3 ca = setCamera(ro, ta, 0.0);

    float aspect = uResolution.x / uResolution.y;

    vec3 total = vec3(0.0);
#if AA>1
    for (int m=0; m < AA; m++)
    for (int n=0; n < AA; n++) { 
        vec2 o = (vec2(float(m), float(n)) / uResolution) / float(AA); // might need to divide (m,n) by resolution!
        vec2 p = vec2(aspect, 1.0) * ( (vUv+o) - vec2(0.5));
    
#else
        vec2 p = vec2(aspect, 1.0) * (vUv - vec2(0.5));
#endif

        // ray direction
        vec3 rd = ca * normalize( vec3(p, 1.2) );

        // ray differentials 
        vec2 px =  vec2(aspect, 1.0) * ( (vUv+vec2(1.0,0.0)) - vec2(0.5));
        vec2 py =  vec2(aspect, 1.0) * ( (vUv+vec2(0.0,1.0)) - vec2(0.5));
        vec3 rdx = ca * normalize( vec3(px, 2.5));
        vec3 rdy = ca * normalize( vec3(py, 2.5));

        vec3 color = render( ro, rd, rdx, rdy );

        color = pow(color, vec3(0.566));

        total += color;
#if AA>1
    }
    total /= float(AA*AA);
#endif
    
    gl_FragColor = vec4( total, 1.0 );
}