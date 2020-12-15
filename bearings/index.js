import * as THREE from 'https://cdnjs.cloudflare.com/ajax/libs/three.js/r123/three.module.min.js';

function main() {
  const canvas = document.querySelector('#c');
  const renderer = new THREE.WebGLRenderer({canvas});
  var count = 0; 

  const fov = 75;
  const aspect = 2;  // the canvas default
  const near = 0.1;
  const far = 100;
  const camera = new THREE.PerspectiveCamera(fov, aspect, near, far);
  camera.position.z = 5;
  camera.position.x = 10;
  camera.position.y = camera.position.z / 2;
  camera.lookAt(0,0,0);

  const scene = new THREE.Scene();
  var light;

  {
    light = new THREE.PointLight(0x657585);
    light.position.set(0,5,0);
    scene.add(light);
  }

  const radius = 6.0;
  const segWidth = 600;
  const segHeight = 600;
  const geometry = new THREE.SphereGeometry(radius, segWidth, segHeight);
  const material = new THREE.ShaderMaterial( {
    uniforms: {
        time: { value: 0.0 }
    },
    vertexShader: document.getElementById( 'vertexShader' ).textContent,
    fragmentShader: document.getElementById( 'fragmentShader' ).textContent
  } );

  // light.lookAt(floor);
  
  // make a mirror cube
  var cubeGeom = new THREE.CubeGeometry(100, 100, 1, 1, 1, 1);

  // Create cube render target
  const cubeRenderTarget = new THREE.WebGLCubeRenderTarget( 512, { format: THREE.RGBFormat, generateMipmaps: true, minFilter: THREE.LinearMipmapLinearFilter } );

  // Create cube camera
  const cubeCamera = new THREE.CubeCamera( 0.1, 100000, cubeRenderTarget );
  scene.add( cubeCamera );

  var mirrorCubeMaterial = new THREE.MeshBasicMaterial( { envMap: cubeRenderTarget.texture,
    reflectivity: 0.35, combine: THREE.MixOperation, color: 0x0 } );
  var mirrorCube = new THREE.Mesh( cubeGeom, mirrorCubeMaterial );
  mirrorCube.position.set(-5, 10, -15);

  cubeCamera.position.copy( mirrorCube.position.add(new THREE.Vector3(0, -15, 0) ) );

  // scene.add(mirrorCube);	

  // add a floor to be less confusing!
  var floorMaterial = new THREE.MeshStandardMaterial( { side: THREE.DoubleSide, emissive: 0x000000 } );
	var floorGeometry = new THREE.PlaneGeometry(100, 100, 10, 10);
	var floor = new THREE.Mesh(floorGeometry, floorMaterial);
  floor.position.y = -5.0;
  floor.position.x = 0;
	floor.rotation.x = Math.PI / 2.0;
  // scene.add(floor);
    
  function makeInstance(geometry, material, x) {
    const mesh = new THREE.Mesh(geometry, material);
    scene.add(mesh);

    mesh.position.x = x;

    return mesh;
  }

  const cubes = [
    makeInstance(geometry, material, 0),
  ];

  function resizeRendererToDisplaySize(renderer) {
    const canvas = renderer.domElement;
    const width = canvas.clientWidth;
    const height = canvas.clientHeight;
    const needResize = canvas.width !== width || canvas.height !== height;
    if (needResize) {
      renderer.setSize(width, height, false);
    }
    return needResize;
  }

  function render(time) {
    time *= 0.001;

    material.uniforms['time'].value = time;

    if (resizeRendererToDisplaySize(renderer)) {
      const canvas = renderer.domElement;
      camera.aspect = canvas.clientWidth / canvas.clientHeight;
      camera.updateProjectionMatrix();
    }

    cubes.forEach((cube, ndx) => {
      const speed = 0.5;
      const rot = time * speed;
      // cube.rotation.x = rot / 13.0;
      cube.rotation.y = -rot / 5.0;

      cube.position.x = 5 * Math.sin( 5 * ( time * 0.025 ) + Math.PI / 4 );
      cube.position.z = 4 * Math.sin( 4 * ( time * 0.025 ) + Math.PI / 4 );
    });

    light.position.x = 5 * Math.sin( 5 * ( time * 0.025 ) + Math.PI / 4 );
    light.position.z = 4 * Math.sin( 4 * ( time * 0.025 ) + Math.PI / 4 );

    camera.lookAt(cubes[0].position);

    // if (count % 2 == 0) {    
    //   cubeCamera.update( renderer, scene );
    //   material.envMap = cubeRenderTarget.texture;
    // } else { 
    //   cubeCamera2.update( renderer, scene );
    //   material.envMap = cubeRenderTarget2.texture;
    // }

    count++;

    cubeCamera.update( renderer, scene );
    
    renderer.render(scene, camera);

    requestAnimationFrame(render);
  }

  requestAnimationFrame(render);
}

main();