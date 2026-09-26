'use strict';

const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const test = require('node:test');
const https = require('https');

const {
  callArkImageAPI,
  generateImage,
  ImageFunctionError,
  _private
} = require('./image-generate');
const { getImageStatus } = require('./image-get-status');

const SECRET = 'test-only-secret-with-at-least-32-characters';
const BASE_ENV = {
  ARK_API_KEY: 'test-api-key',
  ARK_IMAGE_MODEL: 'test-model',
  ARK_IMAGE_URL_HOST_SUFFIXES: 'volces.com',
  IMAGE_TASK_SECRET: SECRET,
  IMAGE_TASK_TTL_MS: '60000'
};

test('built-in reference images are resolved as protagonist then scene inputs', () => {
  assert.deepEqual(_private.buildReferenceImageInputs({
    character: {
      protagonistImageUrl: 'https://cdn.example.com/protagonist.png',
      referenceImageUrl: 'https://cdn.example.com/scene.png'
    }
  }, true), [
    'https://cdn.example.com/protagonist.png',
    'https://cdn.example.com/scene.png'
  ]);
  assert.deepEqual(_private.buildReferenceImageInputs({
    character: { protagonistImageUrl: 'data:image/png;base64,abc' }
  }, true), []);
  assert.deepEqual(_private.buildReferenceImageInputs({
    character: { protagonistImageUrl: 'https://cdn.example.com/protagonist.png' }
  }, false), []);
});

test('character-reference mode fails explicitly when no built-in image is configured', async () => {
  let called = false;
  const result = await generateImage({
    userId: 'u1',
    prompt: 'A comic panel',
    useCharacterReference: true
  }, context(), undefined, {
    characterConfig: { character: {} },
    callArkImageAPI: async () => {
      called = true;
      return { data: [{ url: 'https://ark-project.tos-cn-beijing.volces.com/result.png' }] };
    }
  });

  assert.equal(called, false);
  assert.equal(result.success, false);
  assert.equal(result.errorCode, 'CONFIGURATION_ERROR');
});

test('comic generation passes both built-in images to Ark', async () => {
  let capturedRequest;
  const result = await generateImage({
    userId: 'u1',
    prompt: 'A comic panel',
    style: 'comic',
    useCharacterReference: true
  }, context(), undefined, {
    characterConfig: {
      character: {
        protagonistImageUrl: 'https://cdn.example.com/protagonist.png',
        referenceImageUrl: 'https://cdn.example.com/scene.png'
      }
    },
    callArkImageAPI: async (request) => {
      capturedRequest = request;
      return { data: [{ url: 'https://ark-project.tos-cn-beijing.volces.com/result.png' }] };
    }
  });

  assert.equal(result.success, true);
  assert.deepEqual(capturedRequest.image, [
    'https://cdn.example.com/protagonist.png',
    'https://cdn.example.com/scene.png'
  ]);
  assert.equal(Object.hasOwn(capturedRequest, 'reference_image'), false);
});

test('bundled reference assets are converted to Ark data URLs', () => {
  const protagonist = _private.readReferenceImageAsset('assets/protagonist.png', __dirname);
  const scene = _private.readReferenceImageAsset('assets/scene-reference.png', __dirname);
  assert.match(protagonist, /^data:image\/png;base64,/);
  assert.match(scene, /^data:image\/png;base64,/);
  assert.equal(_private.readReferenceImageAsset('../character.png', __dirname), '');
});

function context(overrides = {}) {
  return { env: { ...BASE_ENV, ...overrides } };
}

test('successful synchronous generation returns a real resolvable receipt', async () => {
  const now = 1_800_000_000_000;
  const imageUrl = 'https://ark-project.tos-cn-beijing.volces.com/private/result.png?token=signed';
  let capturedRequest;
  let capturedTimeout;
  const result = await generateImage({
    userId: 'user-from-client',
    prompt: 'A warm comic panel',
    style: 'comic',
    size: '1024x1024'
  }, context(), undefined, {
    now: () => now,
    callArkImageAPI: async (request, _apiKey, timeoutMs) => {
      capturedRequest = request;
      capturedTimeout = timeoutMs;
      return { data: [{ url: imageUrl }] };
    }
  });

  assert.equal(result.success, true);
  assert.equal(result.status, 'success');
  assert.equal(result.imageUrl, imageUrl);
  assert.equal(result.taskExpiresAt, now + 60000);
  assert.match(result.taskId, /^img1\./);
  assert.equal(result.taskId.includes('volces'), false);
  assert.equal(Object.hasOwn(capturedRequest, 'stream'), false);
  assert.equal(capturedRequest.response_format, 'url');
  assert.equal(capturedTimeout, 50000);

  const status = getImageStatus({ taskId: result.taskId }, context(), undefined, {
    now: () => now + 1
  });
  assert.deepEqual(status, {
    success: true,
    taskId: result.taskId,
    status: 'success',
    progress: 100,
    imageUrl,
    taskExpiresAt: now + 60000
  });
});

test('generation accepts Cloud Foundation body-wrapped event payloads', async () => {
  const imageUrl = 'https://ark-project.tos-cn-beijing.volces.com/result.png';
  const result = await generateImage({
    body: JSON.stringify({
      userId: 'wrapped-user',
      prompt: 'A wrapped comic request',
      style: 'comic',
      size: '1024x1024'
    })
  }, context(), undefined, {
    callArkImageAPI: async () => ({ data: [{ url: imageUrl }] })
  });

  assert.equal(result.success, true);
  assert.equal(result.imageUrl, imageUrl);
});

test('generation accepts a JSON-string event payload', async () => {
  const imageUrl = 'https://ark-project.tos-cn-beijing.volces.com/result.png';
  const result = await generateImage(JSON.stringify({
    userId: 'string-user',
    prompt: 'A string request'
  }), context(), undefined, {
    callArkImageAPI: async () => ({ data: [{ url: imageUrl }] })
  });

  assert.equal(result.success, true);
  assert.equal(result.imageUrl, imageUrl);
});

test('missing production configuration fails before calling Ark and returns no fake taskId', async () => {
  let called = false;
  const result = await generateImage({ userId: 'u1', prompt: 'hello' }, context({
    ARK_API_KEY: ''
  }), undefined, {
    callArkImageAPI: async () => {
      called = true;
      return {};
    }
  });

  assert.equal(called, false);
  assert.equal(result.success, false);
  assert.equal(result.status, 'failed');
  assert.equal(result.errorCode, 'CONFIGURATION_ERROR');
  assert.equal(Object.hasOwn(result, 'taskId'), false);
});

test('invalid request is rejected without leaking input', async () => {
  const result = await generateImage({ userId: 'u1', prompt: '   ' }, context());
  assert.equal(result.success, false);
  assert.equal(result.errorCode, 'INVALID_ARGUMENT');
  assert.equal(Object.hasOwn(result, 'taskId'), false);
});

test('upstream failure stays failed and is marked retryable', async () => {
  const result = await generateImage({ userId: 'u1', prompt: 'hello' }, context(), undefined, {
    callArkImageAPI: async () => {
      throw new ImageFunctionError('UPSTREAM_TIMEOUT', 'timed out', true);
    }
  });

  assert.equal(result.success, false);
  assert.equal(result.status, 'failed');
  assert.equal(result.errorCode, 'UPSTREAM_TIMEOUT');
  assert.equal(result.retryable, true);
  assert.equal(Object.hasOwn(result, 'taskId'), false);
});

test('unsafe or unexpected image URL is rejected', async () => {
  for (const imageUrl of [
    'http://ark-project.tos-cn-beijing.volces.com/result.png',
    'https://127.0.0.1/result.png',
    'https://[::1]/result.png',
    'https://images.example.com/result.png'
  ]) {
    const result = await generateImage({ userId: 'u1', prompt: 'hello' }, context(), undefined, {
      callArkImageAPI: async () => ({ data: [{ url: imageUrl }] })
    });
    assert.equal(result.success, false, imageUrl);
    assert.equal(result.errorCode, 'UPSTREAM_RESPONSE_ERROR', imageUrl);
  }
});

test('tampered and expired receipts return terminal failed status', async () => {
  const now = 1_800_000_000_000;
  const generated = await generateImage({ userId: 'u1', prompt: 'hello' }, context(), undefined, {
    now: () => now,
    callArkImageAPI: async () => ({
      data: [{ url: 'https://ark-project.tos-cn-beijing.volces.com/result.png' }]
    })
  });

  const tampered = `${generated.taskId.slice(0, -1)}${generated.taskId.endsWith('A') ? 'B' : 'A'}`;
  const invalidStatus = getImageStatus({ taskId: tampered }, context(), undefined, {
    now: () => now + 1
  });
  assert.equal(invalidStatus.status, 'failed');
  assert.equal(invalidStatus.errorCode, 'INVALID_TASK_ID');

  const expiredStatus = getImageStatus({ taskId: generated.taskId }, context(), undefined, {
    now: () => now + 60000
  });
  assert.equal(expiredStatus.status, 'failed');
  assert.equal(expiredStatus.errorCode, 'TASK_EXPIRED');
});

test('status accepts Cloud Foundation body-wrapped event payloads', async () => {
  const now = 1_800_000_000_000;
  const imageUrl = 'https://ark-project.tos-cn-beijing.volces.com/result.png';
  const generated = await generateImage({ userId: 'u1', prompt: 'hello' }, context(), undefined, {
    now: () => now,
    callArkImageAPI: async () => ({ data: [{ url: imageUrl }] })
  });

  const status = getImageStatus({
    body: JSON.stringify({ taskId: generated.taskId })
  }, context(), undefined, { now: () => now + 1 });

  assert.equal(status.success, true);
  assert.equal(status.imageUrl, imageUrl);
});

test('Ark request has an enforced timeout', async () => {
  const originalRequest = https.request;
  let timeoutHandler;

  https.request = (_options, _onResponse) => {
    const request = new EventEmitter();
    request.setTimeout = (_timeout, handler) => {
      timeoutHandler = handler;
    };
    request.write = () => {};
    request.end = () => {
      timeoutHandler();
    };
    request.destroy = (error) => {
      request.emit('error', error);
    };
    return request;
  };

  try {
    await assert.rejects(
      callArkImageAPI({ model: 'm', prompt: 'p' }, 'key', 5000),
      (error) => error.code === 'UPSTREAM_TIMEOUT' && error.retryable === true
    );
  } finally {
    https.request = originalRequest;
  }
});

test('Ark HTTP errors preserve retry semantics without returning upstream details', async () => {
  const originalRequest = https.request;

  https.request = (_options, onResponse) => {
    const request = new EventEmitter();
    request.setTimeout = () => {};
    request.write = () => {};
    request.end = () => {
      const response = new EventEmitter();
      response.statusCode = 429;
      onResponse(response);
      response.emit('data', Buffer.from(JSON.stringify({
        error: { message: 'sensitive upstream detail' }
      })));
      response.emit('end');
    };
    request.destroy = (error) => request.emit('error', error);
    return request;
  };

  try {
    await assert.rejects(
      callArkImageAPI({ model: 'm', prompt: 'p' }, 'key', 5000),
      (error) =>
        error.code === 'UPSTREAM_HTTP_ERROR' &&
        error.retryable === true &&
        error.message.includes('HTTP 429') &&
        !error.message.includes('sensitive upstream detail')
    );
  } finally {
    https.request = originalRequest;
  }
});

test('missing task secret makes status lookup fail closed', () => {
  const result = getImageStatus({ taskId: 'img1.not-a-real-token' }, context({
    IMAGE_TASK_SECRET: ''
  }));
  assert.equal(result.success, false);
  assert.equal(result.status, 'failed');
  assert.equal(result.errorCode, 'CONFIGURATION_ERROR');
});

test('oversized task id is rejected without reflecting attacker input', () => {
  const result = getImageStatus({ taskId: 'x'.repeat(8193) }, context());
  assert.equal(result.status, 'failed');
  assert.equal(result.errorCode, 'INVALID_ARGUMENT');
  assert.equal(result.taskId, '');
});
