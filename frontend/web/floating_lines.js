/* floating_lines.js — Vanilla Three.js port of FloatingLines React component */
(function () {

    var vertexShader = `
precision highp float;
void main() {
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}
`;

    var fragmentShader = `
precision highp float;

uniform float iTime;
uniform vec3  iResolution;
uniform float animationSpeed;

uniform bool enableTop;
uniform bool enableMiddle;
uniform bool enableBottom;

uniform int topLineCount;
uniform int middleLineCount;
uniform int bottomLineCount;

uniform float topLineDistance;
uniform float middleLineDistance;
uniform float bottomLineDistance;

uniform vec3 topWavePosition;
uniform vec3 middleWavePosition;
uniform vec3 bottomWavePosition;

uniform vec2 iMouse;
uniform bool interactive;
uniform float bendRadius;
uniform float bendStrength;
uniform float bendInfluence;

uniform bool parallax;
uniform float parallaxStrength;
uniform vec2 parallaxOffset;

uniform vec3 lineGradient[8];
uniform int lineGradientCount;

const vec3 BLACK = vec3(0.0);
const vec3 PINK  = vec3(233.0, 71.0, 245.0) / 255.0;
const vec3 BLUE  = vec3(47.0,  75.0, 162.0) / 255.0;

mat2 rotate(float r) {
  return mat2(cos(r), sin(r), -sin(r), cos(r));
}

vec3 background_color(vec2 uv) {
  vec3 col = vec3(0.0);
  float y = sin(uv.x - 0.2) * 0.3 - 0.1;
  float m = uv.y - y;
  col += mix(BLUE, BLACK, smoothstep(0.0, 1.0, abs(m)));
  col += mix(PINK, BLACK, smoothstep(0.0, 1.0, abs(m - 0.8)));
  return col * 0.5;
}

vec3 getLineColor(float t, vec3 baseColor) {
  if (lineGradientCount <= 0) return baseColor;
  if (lineGradientCount == 1) return lineGradient[0];
  float clampedT = clamp(t, 0.0, 0.9999);
  float scaled = clampedT * float(lineGradientCount - 1);
  int idx = int(floor(scaled));
  float f = fract(scaled);
  int idx2 = min(idx + 1, lineGradientCount - 1);
  return mix(lineGradient[idx], lineGradient[idx2], f) * 0.5;
}

float wave(vec2 uv, float offset, vec2 screenUv, vec2 mouseUv, bool shouldBend) {
  float time = iTime * animationSpeed;
  float x_offset   = offset;
  float x_movement = time * 0.1;
  float amp        = sin(offset + time * 0.2) * 0.3;
  float y          = sin(uv.x + x_offset + x_movement) * amp;

  if (shouldBend) {
    vec2 d = screenUv - mouseUv;
    float influence = exp(-dot(d, d) * bendRadius);
    float bendOffset = (mouseUv.y - screenUv.y) * influence * bendStrength * bendInfluence;
    y += bendOffset;
  }

  float m = uv.y - y;
  return 0.0175 / max(abs(m) + 0.01, 1e-3) + 0.01;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 baseUv = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
  baseUv.y *= -1.0;
  if (parallax) baseUv += parallaxOffset;

  vec3 col = vec3(0.0);
  vec3 b = lineGradientCount > 0 ? vec3(0.0) : background_color(baseUv);

  vec2 mouseUv = vec2(0.0);
  if (interactive) {
    mouseUv = (2.0 * iMouse - iResolution.xy) / iResolution.y;
    mouseUv.y *= -1.0;
  }

  if (enableBottom) {
    for (int i = 0; i < 20; ++i) {
      if (i >= bottomLineCount) break;
      float fi = float(i);
      float t = fi / max(float(bottomLineCount - 1), 1.0);
      vec3 lineCol = getLineColor(t, b);
      float angle = bottomWavePosition.z * log(length(baseUv) + 1.0);
      vec2 ruv = baseUv * rotate(angle);
      col += lineCol * wave(
        ruv + vec2(bottomLineDistance * fi + bottomWavePosition.x, bottomWavePosition.y),
        1.5 + 0.2 * fi, baseUv, mouseUv, interactive
      ) * 0.2;
    }
  }

  if (enableMiddle) {
    for (int i = 0; i < 20; ++i) {
      if (i >= middleLineCount) break;
      float fi = float(i);
      float t = fi / max(float(middleLineCount - 1), 1.0);
      vec3 lineCol = getLineColor(t, b);
      float angle = middleWavePosition.z * log(length(baseUv) + 1.0);
      vec2 ruv = baseUv * rotate(angle);
      col += lineCol * wave(
        ruv + vec2(middleLineDistance * fi + middleWavePosition.x, middleWavePosition.y),
        2.0 + 0.15 * fi, baseUv, mouseUv, interactive
      );
    }
  }

  if (enableTop) {
    for (int i = 0; i < 20; ++i) {
      if (i >= topLineCount) break;
      float fi = float(i);
      float t = fi / max(float(topLineCount - 1), 1.0);
      vec3 lineCol = getLineColor(t, b);
      float angle = topWavePosition.z * log(length(baseUv) + 1.0);
      vec2 ruv = baseUv * rotate(angle);
      ruv.x *= -1.0;
      col += lineCol * wave(
        ruv + vec2(topLineDistance * fi + topWavePosition.x, topWavePosition.y),
        1.0 + 0.2 * fi, baseUv, mouseUv, interactive
      ) * 0.1;
    }
  }

  fragColor = vec4(col, 1.0);
}

void main() {
  vec4 color = vec4(0.0);
  mainImage(color, gl_FragCoord.xy);
  gl_FragColor = color;
}
`;

    function hexToVec3(hex) {
        var value = hex.trim().replace(/^#/, '');
        var r = 1, g = 1, b_ = 1;
        if (value.length === 3) {
            r = parseInt(value[0] + value[0], 16) / 255;
            g = parseInt(value[1] + value[1], 16) / 255;
            b_ = parseInt(value[2] + value[2], 16) / 255;
        } else if (value.length === 6) {
            r = parseInt(value.slice(0, 2), 16) / 255;
            g = parseInt(value.slice(2, 4), 16) / 255;
            b_ = parseInt(value.slice(4, 6), 16) / 255;
        }
        return new THREE.Vector3(r, g, b_);
    }

    window.createFloatingLines = function (containerId, opts) {
        opts = opts || {};

        var container = document.getElementById(containerId);
        if (!container) return null;

        var enabledWaves = opts.enabledWaves || ['top', 'middle', 'bottom'];
        var lineCount = opts.lineCount !== undefined ? opts.lineCount : 5;
        var lineDistance = opts.lineDistance !== undefined ? opts.lineDistance : 5;
        var animationSpeed = opts.animationSpeed !== undefined ? opts.animationSpeed : 1;
        var interactive = opts.interactive !== undefined ? opts.interactive : true;
        var bendRadius = opts.bendRadius !== undefined ? opts.bendRadius : 5.0;
        var bendStrength = opts.bendStrength !== undefined ? opts.bendStrength : -0.5;
        var mouseDamping = opts.mouseDamping !== undefined ? opts.mouseDamping : 0.05;
        var parallaxEnabled = opts.parallax !== undefined ? opts.parallax : true;
        var parallaxStrength = opts.parallaxStrength !== undefined ? opts.parallaxStrength : 0.2;
        var linesGradient = opts.linesGradient || null;

        var topWavePos = opts.topWavePosition || { x: 10.0, y: 0.5, rotate: -0.4 };
        var midWavePos = opts.middleWavePosition || { x: 5.0, y: 0.0, rotate: 0.2 };
        var botWavePos = opts.bottomWavePosition || { x: 2.0, y: -0.7, rotate: 0.4 };

        function getCount(wave) {
            if (typeof lineCount === 'number') return lineCount;
            var idx = enabledWaves.indexOf(wave);
            return idx >= 0 ? (lineCount[idx] || 6) : 0;
        }
        function getDist(wave) {
            if (typeof lineDistance === 'number') return lineDistance;
            var idx = enabledWaves.indexOf(wave);
            return idx >= 0 ? (lineDistance[idx] || 5) : 5;
        }

        var topCount = enabledWaves.includes('top') ? getCount('top') : 0;
        var midCount = enabledWaves.includes('middle') ? getCount('middle') : 0;
        var botCount = enabledWaves.includes('bottom') ? getCount('bottom') : 0;
        var topDist = (enabledWaves.includes('top') ? getDist('top') : 5) * 0.01;
        var midDist = (enabledWaves.includes('middle') ? getDist('middle') : 5) * 0.01;
        var botDist = (enabledWaves.includes('bottom') ? getDist('bottom') : 5) * 0.01;

        var scene = new THREE.Scene();
        var camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
        camera.position.z = 1;

        var renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
        renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
        renderer.domElement.style.width = '100%';
        renderer.domElement.style.height = '100%';

        while (container.firstChild) container.removeChild(container.firstChild);
        container.appendChild(renderer.domElement);

        var MAX_GRAD = 8;
        var gradColors = Array.from({ length: MAX_GRAD }, function () { return new THREE.Vector3(1, 1, 1); });
        var gradCount = 0;

        if (linesGradient && linesGradient.length > 0) {
            var stops = linesGradient.slice(0, MAX_GRAD);
            gradCount = stops.length;
            stops.forEach(function (hex, i) {
                var v = hexToVec3(hex);
                gradColors[i].set(v.x, v.y, v.z);
            });
        }

        var uniforms = {
            iTime: { value: 0 },
            iResolution: { value: new THREE.Vector3(1, 1, 1) },
            animationSpeed: { value: animationSpeed },
            enableTop: { value: enabledWaves.includes('top') },
            enableMiddle: { value: enabledWaves.includes('middle') },
            enableBottom: { value: enabledWaves.includes('bottom') },
            topLineCount: { value: topCount },
            middleLineCount: { value: midCount },
            bottomLineCount: { value: botCount },
            topLineDistance: { value: topDist },
            middleLineDistance: { value: midDist },
            bottomLineDistance: { value: botDist },
            topWavePosition: { value: new THREE.Vector3(topWavePos.x, topWavePos.y, topWavePos.rotate) },
            middleWavePosition: { value: new THREE.Vector3(midWavePos.x, midWavePos.y, midWavePos.rotate) },
            bottomWavePosition: { value: new THREE.Vector3(botWavePos.x, botWavePos.y, botWavePos.rotate) },
            iMouse: { value: new THREE.Vector2(-1000, -1000) },
            interactive: { value: interactive },
            bendRadius: { value: bendRadius },
            bendStrength: { value: bendStrength },
            bendInfluence: { value: 0 },
            parallax: { value: parallaxEnabled },
            parallaxStrength: { value: parallaxStrength },
            parallaxOffset: { value: new THREE.Vector2(0, 0) },
            lineGradient: { value: gradColors },
            lineGradientCount: { value: gradCount }
        };

        var material = new THREE.ShaderMaterial({ uniforms: uniforms, vertexShader: vertexShader, fragmentShader: fragmentShader });
        var geometry = new THREE.PlaneGeometry(2, 2);
        scene.add(new THREE.Mesh(geometry, material));

        var targetMouse = new THREE.Vector2(-1000, -1000);
        var currentMouse = new THREE.Vector2(-1000, -1000);
        var targetInfluence = 0, currentInfluence = 0;
        var targetParallax = new THREE.Vector2(0, 0);
        var currentParallax = new THREE.Vector2(0, 0);

        function setSize() {
            var w = container.clientWidth || window.innerWidth;
            var h = container.clientHeight || window.innerHeight;
            renderer.setSize(w, h, false);
            var cw = renderer.domElement.width;
            var ch = renderer.domElement.height;
            uniforms.iResolution.value.set(cw, ch, 1);
        }
        setSize();

        var ro = (typeof ResizeObserver !== 'undefined') ? new ResizeObserver(setSize) : null;
        if (ro) ro.observe(container);

        function onPointerMove(e) {
            var rect = renderer.domElement.getBoundingClientRect();
            var x = e.clientX - rect.left;
            var y = e.clientY - rect.top;
            var dpr = renderer.getPixelRatio();
            targetMouse.set(x * dpr, (rect.height - y) * dpr);
            targetInfluence = 1.0;
            if (parallaxEnabled) {
                var cx = rect.width / 2, cy = rect.height / 2;
                targetParallax.set(((x - cx) / rect.width) * parallaxStrength, ((-(y - cy)) / rect.height) * parallaxStrength);
            }
        }
        function onPointerLeave() { targetInfluence = 0.0; }

        if (interactive) {
            renderer.domElement.addEventListener('pointermove', onPointerMove);
            renderer.domElement.addEventListener('pointerleave', onPointerLeave);
        }

        var clock = new THREE.Clock();
        var rafId;

        function loop() {
            rafId = requestAnimationFrame(loop);
            uniforms.iTime.value = clock.getElapsedTime();
            if (interactive) {
                currentMouse.lerp(targetMouse, mouseDamping);
                uniforms.iMouse.value.copy(currentMouse);
                currentInfluence += (targetInfluence - currentInfluence) * mouseDamping;
                uniforms.bendInfluence.value = currentInfluence;
            }
            if (parallaxEnabled) {
                currentParallax.lerp(targetParallax, mouseDamping);
                uniforms.parallaxOffset.value.copy(currentParallax);
            }
            renderer.render(scene, camera);
        }
        loop();

        return {
            destroy: function () {
                cancelAnimationFrame(rafId);
                if (ro) ro.disconnect();
                if (interactive) {
                    renderer.domElement.removeEventListener('pointermove', onPointerMove);
                    renderer.domElement.removeEventListener('pointerleave', onPointerLeave);
                }
                geometry.dispose();
                material.dispose();
                renderer.dispose();
                if (renderer.domElement.parentElement) {
                    renderer.domElement.parentElement.removeChild(renderer.domElement);
                }
            }
        };
    };

})();
