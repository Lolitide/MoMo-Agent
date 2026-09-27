import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const testDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(testDir, '..');

const read = async (relativePath) =>
  readFile(path.join(root, relativePath), 'utf8');

const [schemaText, modelSource, dbSource, storageSource, syncSource] = await Promise.all([
  read('objecttypes.json'),
  read('entry/src/main/ets/service/cloud/CloudDBModels.ets'),
  read('entry/src/main/ets/service/cloud/CloudDBService.ets'),
  read('entry/src/main/ets/service/cloud/CloudStorageService.ets'),
  read('entry/src/main/ets/service/DataSyncService.ets')
]);

const schema = JSON.parse(schemaText);
const expectedFields = {
  UserProfile: ['userId', 'username', 'avatar', 'email', 'phone', 'createdAt', 'updatedAt',
    'llmQuotaDaily', 'llmQuotaUsed', 'imageQuotaDaily', 'imageQuotaUsed', 'lastQuotaReset'],
  DailyRecord: ['recordId', 'userId', 'date', 'mood', 'events', 'summary', 'comicScript',
    'comicImages', 'createdAt', 'updatedAt'],
  ComicImage: ['imageId', 'userId', 'recordId', 'panelIndex', 'prompt', 'imageUrl', 'localPath',
    'status', 'taskId', 'createdAt', 'completedAt'],
  UserFeedback: ['feedbackId', 'userId', 'type', 'content', 'contact', 'status', 'createdAt'],
  LongTermMemory: ['memoryId', 'userId', 'title', 'date', 'dateTimestamp', 'summary', 'content',
    'type', 'importance', 'tags', 'sourceEvents', 'relatedMemoryIds', 'createdAt', 'updatedAt']
};
const expectedIndexes = {
  UserProfile: [['updatedAt']],
  DailyRecord: [['userId', 'date'], ['updatedAt']],
  ComicImage: [['recordId', 'panelIndex'], ['userId']],
  UserFeedback: [['userId', 'createdAt'], ['status']],
  LongTermMemory: [['userId', 'dateTimestamp'], ['type'], ['updatedAt']]
};

assert.deepEqual(
  schema.objectTypes.map((item) => item.objectTypeName).sort(),
  Object.keys(expectedFields).sort(),
  'schema object types changed unexpectedly'
);

for (const objectType of schema.objectTypes) {
  const expected = expectedFields[objectType.objectTypeName];
  assert.deepEqual(objectType.fields.map((field) => field.fieldName), expected,
    `${objectType.objectTypeName} fields do not match the client contract`);
  const classStart = modelSource.indexOf(`export class ${objectType.objectTypeName}`);
  const constructorStart = modelSource.indexOf('constructor(', classStart);
  assert.ok(classStart >= 0 && constructorStart > classStart,
    `${objectType.objectTypeName} client model is missing`);
  const fieldSection = modelSource.slice(classStart, constructorStart);
  for (const field of expected) {
    assert.match(fieldSection, new RegExp(`\\b${field}\\s*:`),
      `${objectType.objectTypeName}.${field} is absent from CloudDBModels.ets`);
  }
  assert.deepEqual(objectType.indexes.map((index) => index.indexList), expectedIndexes[objectType.objectTypeName],
    `${objectType.objectTypeName} query indexes changed unexpectedly`);
  const primaryKeys = objectType.fields.filter((field) => field.belongPrimaryKey);
  assert.equal(primaryKeys.length, 1, `${objectType.objectTypeName} must have exactly one primary key`);
}

for (const permission of schema.permissions) {
  const byRole = Object.fromEntries(permission.permissions.map((item) => [item.role, item.rights]));
  assert.deepEqual(byRole.World, [], `${permission.objectTypeName} must not grant World access`);
  assert.deepEqual(byRole.Authenticated, [],
    `${permission.objectTypeName} must not grant blanket Authenticated access`);
  assert.deepEqual(byRole.Creator, ['Read', 'Upsert', 'Delete'],
    `${permission.objectTypeName} Creator ACL contract changed`);
  assert.deepEqual(byRole.Administrator, ['Read', 'Upsert', 'Delete'],
    `${permission.objectTypeName} Administrator ACL contract changed`);
}

assert.match(dbSource, /bindVerifiedUser\(userId: string\)/);
assert.match(dbSource, /data userId|数据 userId 与当前云身份不一致/);
assert.match(dbSource, /equalTo\('recordId', recordId\)\.equalTo\('userId', userId\)/);
assert.doesNotMatch(dbSource, /获取记录列表失败:[\s\S]{0,180}return \[\]/,
  'database failures must not be disguised as empty results');

assert.match(storageSource, /private static readonly DEFAULT_BUCKET = 'momo-images'/);
assert.match(storageSource, /validateOwnedRemotePath/);
assert.match(storageSource, /task\.on\('completed'/);
assert.match(storageSource, /task\.on\('failed'/);
assert.match(storageSource, /localPath: `image_cache\/\$\{filename\}`/);
assert.match(storageSource, /下载地址不是当前私有存储桶 URL/);

const initializeStart = syncSource.indexOf('async initialize(context?: Context)');
const activateStart = syncSource.indexOf('async activateVerifiedCloudSync');
assert.ok(initializeStart >= 0 && activateStart > initializeStart);
const defaultInitialize = syncSource.slice(initializeStart, activateStart);
assert.doesNotMatch(defaultInitialize, /cloudManager\.initialize/,
  'default startup must not initialize cloud sync for an unverified guest identity');
assert.match(syncSource, /DataSyncMode\.LOCAL_ONLY/);
assert.match(syncSource, /migrateGuestMemoriesAfterConsent/);
assert.match(syncSource, /skippedExisting/);

console.log('T3 contract checks passed: schema, ACL, ownership guards, local guest mode, and migration safety.');
