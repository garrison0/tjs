import * as THREE from 'https://cdnjs.cloudflare.com/ajax/libs/three.js/r123/three.module.min.js';

function main () {
  const canvas = document.querySelector('#c');
  const renderer = new THREE.WebGLRenderer({canvas});
  const scene = new THREE.Scene();
  var previousTime = 0;

  const fov = 75;
  const aspect = 2;  // the canvas default
  const near = 0.1;
  const far = 1000;
  const camera = new THREE.PerspectiveCamera(fov, aspect, near, far);

  var quadMaterial = new THREE.ShaderMaterial({
    uniforms: {
      uResolution: new THREE.Uniform( new THREE.Vector2(canvas.clientWidth, canvas.clientHeight) ),
      uTime: {value: 0}
    },
    vertexShader: document.getElementById('vertexShader').textContent,
    fragmentShader: document.getElementById('fragmentShader').textContent,
    depthWrite: false,
    depthTest: false
  });

  var quad = new THREE.Mesh(
    new THREE.PlaneGeometry(2, 2),
    quadMaterial
  );
  scene.add(quad);

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
    time = time * 0.001;
    const dt = time - previousTime;
    previousTime = time;

    quadMaterial.uniforms['uTime'].value = time;

    if (resizeRendererToDisplaySize(renderer)) {
      const canvas = renderer.domElement;
      camera.aspect = canvas.clientWidth / canvas.clientHeight;
      camera.updateProjectionMatrix();
    }

    renderer.render(scene, camera);

    requestAnimationFrame(render);
  }

  requestAnimationFrame(render);
}

main();