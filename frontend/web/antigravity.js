window.createAntigravity = function (containerId, options = {}) {
    const container = document.getElementById(containerId);
    if (!container) return null;

    const count = options.count || 300;
    const magnetRadius = options.magnetRadius || 10;
    const ringRadius = options.ringRadius || 10;
    const waveSpeed = options.waveSpeed || 0.4;
    const waveAmplitude = options.waveAmplitude || 1;
    const particleSize = options.particleSize || 2;
    const lerpSpeed = options.lerpSpeed || 0.1;
    const color = options.color || '#FF9FFC';
    const autoAnimate = options.autoAnimate !== undefined ? options.autoAnimate : false;
    const particleVariance = options.particleVariance || 1;
    const rotationSpeed = options.rotationSpeed || 0;
    const depthFactor = options.depthFactor || 1;
    const pulseSpeed = options.pulseSpeed || 3;
    const fieldStrength = options.fieldStrength || 10;
    const particleShape = options.particleShape || 'capsule';

    let width = container.clientWidth || window.innerWidth;
    let height = container.clientHeight || window.innerHeight;

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(35, width / height, 0.1, 1000);
    camera.position.z = 50;

    const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
    renderer.setSize(width, height);
    renderer.setPixelRatio(window.devicePixelRatio);

    while (container.firstChild) container.removeChild(container.firstChild);
    container.appendChild(renderer.domElement);

    const particles = [];

    const getViewportSize = () => {
        const vHeight = 2 * Math.tan((35 / 2) * Math.PI / 180) * 50;
        const vWidth = vHeight * (width / height);
        return { vWidth, vHeight };
    };

    const { vWidth, vHeight } = getViewportSize();

    for (let i = 0; i < count; i++) {
        const t = Math.random() * 100;
        const speed = 0.01 + Math.random() / 200;

        const x = (Math.random() - 0.5) * vWidth;
        const y = (Math.random() - 0.5) * vHeight;
        const z = (Math.random() - 0.5) * 20;

        const randomRadiusOffset = (Math.random() - 0.5) * 2;

        particles.push({
            t, speed,
            mx: x, my: y, mz: z,
            cx: x, cy: y, cz: z,
            randomRadiusOffset
        });
    }

    let geometry;
    if (particleShape === 'capsule' && THREE.CapsuleGeometry) {
        geometry = new THREE.CapsuleGeometry(0.1, 0.4, 4, 8);
    } else if (particleShape === 'sphere') {
        geometry = new THREE.SphereGeometry(0.2, 16, 16);
    } else if (particleShape === 'box') {
        geometry = new THREE.BoxGeometry(0.3, 0.3, 0.3);
    } else if (particleShape === 'tetrahedron') {
        geometry = new THREE.TetrahedronGeometry(0.3);
    } else {
        geometry = new THREE.CylinderGeometry(0.1, 0.1, 0.4, 8);
    }

    const material = new THREE.MeshBasicMaterial({ color: color });
    const mesh = new THREE.InstancedMesh(geometry, material, count);
    scene.add(mesh);

    const dummy = new THREE.Object3D();

    let mouse = { x: 0, y: 0 };
    let lastMousePos = { x: 0, y: 0 };
    let lastMouseMoveTime = 0;
    let virtualMouse = { x: 0, y: 0 };

    const onMouseMove = (event) => {
        const rect = renderer.domElement.getBoundingClientRect();
        mouse.x = ((event.clientX - rect.left) / width) * 2 - 1;
        mouse.y = -((event.clientY - rect.top) / height) * 2 + 1;
    };

    const onTouchMove = (event) => {
        if (event.touches.length > 0) {
            const rect = renderer.domElement.getBoundingClientRect();
            mouse.x = ((event.touches[0].clientX - rect.left) / width) * 2 - 1;
            mouse.y = -((event.touches[0].clientY - rect.top) / height) * 2 + 1;
        }
    };

    window.addEventListener('mousemove', onMouseMove);
    window.addEventListener('touchmove', onTouchMove);

    let animationFrameId;
    const clock = new THREE.Clock();

    const renderLoop = () => {
        animationFrameId = requestAnimationFrame(renderLoop);

        const time = clock.getElapsedTime();
        const { vWidth: currentVWidth, vHeight: currentVHeight } = getViewportSize();

        const mouseDist = Math.sqrt(Math.pow(mouse.x - lastMousePos.x, 2) + Math.pow(mouse.y - lastMousePos.y, 2));
        if (mouseDist > 0.001) {
            lastMouseMoveTime = Date.now();
            lastMousePos = { x: mouse.x, y: mouse.y };
        }

        let destX = (mouse.x * currentVWidth) / 2;
        let destY = (mouse.y * currentVHeight) / 2;

        if (autoAnimate && Date.now() - lastMouseMoveTime > 2000) {
            destX = Math.sin(time * 0.5) * (currentVWidth / 4);
            destY = Math.cos(time * 0.5 * 2) * (currentVHeight / 4);
        }

        const smoothFactor = 0.05;
        virtualMouse.x += (destX - virtualMouse.x) * smoothFactor;
        virtualMouse.y += (destY - virtualMouse.y) * smoothFactor;

        const targetX = virtualMouse.x;
        const targetY = virtualMouse.y;

        const globalRotation = time * rotationSpeed;

        particles.forEach((particle, i) => {
            particle.t += particle.speed / 2;
            const { t, mx, my, mz, randomRadiusOffset } = particle;

            const projectionFactor = 1 - particle.cz / 50;
            const projectedTargetX = targetX * projectionFactor;
            const projectedTargetY = targetY * projectionFactor;

            const dx = mx - projectedTargetX;
            const dy = my - projectedTargetY;
            const dist = Math.sqrt(dx * dx + dy * dy);

            let targetPos = { x: mx, y: my, z: mz * depthFactor };

            if (dist < magnetRadius) {
                const angle = Math.atan2(dy, dx) + globalRotation;
                const wave = Math.sin(t * waveSpeed + angle) * (0.5 * waveAmplitude);
                const deviation = randomRadiusOffset * (5 / (fieldStrength + 0.1));
                const currentRingRadius = ringRadius + wave + deviation;

                targetPos.x = projectedTargetX + currentRingRadius * Math.cos(angle);
                targetPos.y = projectedTargetY + currentRingRadius * Math.sin(angle);
                targetPos.z = mz * depthFactor + Math.sin(t) * (1 * waveAmplitude * depthFactor);
            }

            particle.cx += (targetPos.x - particle.cx) * lerpSpeed;
            particle.cy += (targetPos.y - particle.cy) * lerpSpeed;
            particle.cz += (targetPos.z - particle.cz) * lerpSpeed;

            dummy.position.set(particle.cx, particle.cy, particle.cz);
            dummy.lookAt(projectedTargetX, projectedTargetY, particle.cz);
            dummy.rotateX(Math.PI / 2);

            const currentDistToMouse = Math.sqrt(
                Math.pow(particle.cx - projectedTargetX, 2) + Math.pow(particle.cy - projectedTargetY, 2)
            );

            const distFromRing = Math.abs(currentDistToMouse - ringRadius);
            let scaleFactor = 1 - distFromRing / 10;
            scaleFactor = Math.max(0, Math.min(1, scaleFactor));

            const finalScale = scaleFactor * (0.8 + Math.sin(t * pulseSpeed) * 0.2 * particleVariance) * particleSize;
            dummy.scale.set(finalScale, finalScale, finalScale);

            dummy.updateMatrix();
            mesh.setMatrixAt(i, dummy.matrix);
        });

        mesh.instanceMatrix.needsUpdate = true;
        renderer.render(scene, camera);
    };

    renderLoop();

    const handleResize = () => {
        if (!container) return;
        width = container.clientWidth || window.innerWidth;
        height = container.clientHeight || window.innerHeight;
        renderer.setSize(width, height);
        camera.aspect = width / height;
        camera.updateProjectionMatrix();
    };
    window.addEventListener('resize', handleResize);

    return {
        destroy: () => {
            cancelAnimationFrame(animationFrameId);
            window.removeEventListener('mousemove', onMouseMove);
            window.removeEventListener('touchmove', onTouchMove);
            window.removeEventListener('resize', handleResize);
            if (container && container.contains(renderer.domElement)) {
                container.removeChild(renderer.domElement);
            }
            geometry.dispose();
            material.dispose();
            renderer.dispose();
        }
    };
};
