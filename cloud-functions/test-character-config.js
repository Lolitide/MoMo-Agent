/**
 * 测试角色配置和图片生成功能
 * 使用方法：node test-character-config.js
 */

const fs = require('fs');
const path = require('path');

// 导入云函数
const { _private: imageTest } = require('./image-generate.js');
const { _test: scriptTest } = require('./llm-comic-script.js');

const { loadCharacterConfig: loadImageConfig, enhancePrompt } = imageTest;
const { buildComicScriptPrompt, loadCharacterConfig: loadScriptConfig } = scriptTest;

console.log('=== 测试角色配置系统 ===\n');

// 测试 1: 加载配置文件
console.log('1. 测试配置文件加载...');
try {
  const config = loadScriptConfig();
  if (config && config.character) {
    console.log('✅ 配置文件加载成功');
    console.log('   角色名称:', config.character.name);
    console.log('   角色外观:', config.character.appearance);
    console.log('   主角图URL:', config.character.protagonistImageUrl || '(未设置)');
    console.log('   参考图URL:', config.character.referenceImageUrl || '(未设置)');
  } else {
    console.log('❌ 配置文件格式错误');
  }
} catch (err) {
  console.log('❌ 配置文件加载失败:', err.message);
}

console.log('\n2. 测试 Prompt 增强...');
const testPrompt = 'girl sitting by window, reading a book, afternoon sunlight';
const testStyle = 'comic';

try {
  const enhancedWithChar = enhancePrompt(testPrompt, testStyle, true);
  const enhancedWithoutChar = enhancePrompt(testPrompt, testStyle, false);

  console.log('✅ Prompt 增强成功');
  console.log('\n原始 Prompt:');
  console.log('  ', testPrompt);
  console.log('\n启用角色参考后:');
  console.log('  ', enhancedWithChar);
  console.log('\n未启用角色参考:');
  console.log('  ', enhancedWithoutChar);
} catch (err) {
  console.log('❌ Prompt 增强失败:', err.message);
}

console.log('\n3. 测试漫画脚本生成 Prompt...');
const testSummary = '今天和朋友一起喝了咖啡，聊了很多有趣的事情';
const testEvents = [
  '咖啡店见面',
  '分享近况'
];

try {
  const scriptPrompt = buildComicScriptPrompt(testSummary, testEvents);
  console.log('✅ 脚本 Prompt 构建成功');
  console.log('\n生成的 Prompt (前300字符):');
  console.log('  ', scriptPrompt.substring(0, 300) + '...');

  if (scriptPrompt.includes('默默')) {
    console.log('✅ 已注入角色名称');
  } else {
    console.log('⚠️  未检测到角色名称');
  }
} catch (err) {
  console.log('❌ 脚本 Prompt 构建失败:', err.message);
}

console.log('\n=== 测试完成 ===');
console.log('\n下一步：');
console.log('1. 在 character-config.json 中填入参考图 URL');
console.log('2. 可选：调整角色外观描述和风格关键词');
console.log('3. 在应用中测试真实漫画生成');
