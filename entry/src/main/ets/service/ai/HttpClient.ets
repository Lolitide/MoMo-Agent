/*
 * ============================================================================
 * 文件名：service/ai/HttpClient.ets
 * ============================================================================
 * 【用途】HTTP网络请求封装，基于 @ohos.net.http 提供统一的请求接口
 * 【功能】
 *   - 支持 GET/POST 请求
 *   - 超时控制（默认30秒）
 *   - 重试机制（默认3次）
 *   - 错误统一处理
 *   - JSON自动序列化/反序列化
 * 【参考】
 *   - HarmonyOS官方文档：@ohos.net.http
 *   - 社区封装：axios风格的API设计
 * ============================================================================
 */
import http from '@ohos.net.http';
import { Logger } from '../../utils/Logger';

export interface HttpRequestOptions {
  url: string;
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  headers?: Record<string, string>;
  body?: string | object;
  timeout?: number;  // 毫秒
  retry?: number;    // 重试次数
}

export interface HttpResponse<T = Object> {
  code: number;
  data: T;
  message: string;
  headers?: Record<string, string>;
}

export class HttpClient {
  private static readonly TAG = 'HttpClient';
  private static readonly DEFAULT_TIMEOUT = 30000; // 30秒
  private static readonly DEFAULT_RETRY = 3;

  /**
   * 发起HTTP请求
   */
  static async request<T = Object>(options: HttpRequestOptions): Promise<HttpResponse<T>> {
    const url = options.url;
    const method = options.method || 'GET';
    const headers = options.headers || {};
    const body = options.body;
    const timeout = options.timeout || HttpClient.DEFAULT_TIMEOUT;
    const retry = options.retry || HttpClient.DEFAULT_RETRY;

    let lastError: Error | null = null;

    // 重试逻辑
    for (let attempt = 0; attempt <= retry; attempt++) {
      try {
        if (attempt > 0) {
          Logger.info(HttpClient.TAG, `重试第 ${attempt} 次: ${url}`);
          await HttpClient.delay(1000 * attempt); // 递增延迟
        }

        const response = await HttpClient.doRequest<T>({
          url,
          method,
          headers,
          body,
          timeout
        });

        return response;
      } catch (error) {
        lastError = error as Error;
        Logger.warn(HttpClient.TAG, `请求失败 (${attempt + 1}/${retry + 1}): ${error}`);

        // 如果是客户端错误（4xx），不重试
        if (lastError.message && lastError.message.includes('4')) {
          break;
        }
      }
    }

    // 所有重试都失败
    throw lastError || new Error('HTTP请求失败');
  }

  /**
   * 执行单次HTTP请求
   */
  private static doRequest<T>(options: HttpRequestOptions): Promise<HttpResponse<T>> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp();

      const url = options.url;
      const method = options.method || 'GET';
      const headers = options.headers || {};
      const body = options.body;
      const timeout = options.timeout || HttpClient.DEFAULT_TIMEOUT;

      // 构建请求头
      const finalHeaders: Record<string, string> = {};
      finalHeaders['Content-Type'] = 'application/json';
      if (headers) {
        Object.keys(headers).forEach(key => {
          finalHeaders[key] = headers[key];
        });
      }

      // 构建请求体
      let extraData: string | object | undefined = undefined;
      if (body) {
        if (typeof body === 'string') {
          extraData = body;
        } else {
          extraData = body;
          finalHeaders['Content-Type'] = 'application/json';
        }
      }

      Logger.info(HttpClient.TAG, `${method} ${url}`);

      httpRequest.request(url, {
        method: method as http.RequestMethod,
        header: finalHeaders,
        extraData: extraData,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: timeout,
        readTimeout: timeout
      }, (err, data) => {
        if (err) {
          Logger.error(HttpClient.TAG, `请求错误: ${err.message}`);
          httpRequest.destroy();
          reject(new Error(`网络请求失败: ${err.message}`));
          return;
        }

        try {
          const responseCode = data.responseCode;
          const resultStr = data.result as string;

          Logger.info(HttpClient.TAG, `响应码: ${responseCode}, 数据长度: ${resultStr.length}`);

          if (responseCode >= 200 && responseCode < 300) {
            // 成功响应
            let parsedData: T;
            try {
              parsedData = JSON.parse(resultStr) as T;
            } catch (parseErr) {
              // 如果不是JSON，直接返回字符串
              parsedData = resultStr as T;
            }

            resolve({
              code: responseCode,
              data: parsedData,
              message: 'success',
              headers: data.header as Record<string, string>
            });
          } else {
            // HTTP错误
            reject(new Error(`HTTP ${responseCode}: ${resultStr.substring(0, 200)}`));
          }
        } catch (error) {
          Logger.error(HttpClient.TAG, `解析响应失败: ${error}`);
          reject(error);
        } finally {
          httpRequest.destroy();
        }
      });
    });
  }

  /**
   * GET请求
   */
  static async get<T = Object>(url: string, headers?: Record<string, string>): Promise<HttpResponse<T>> {
    return HttpClient.request<T>({ url: url, method: 'GET', headers: headers });
  }

  /**
   * POST请求
   */
  static async post<T = Object>(
    url: string,
    body?: string | object,
    headers?: Record<string, string>
  ): Promise<HttpResponse<T>> {
    return HttpClient.request<T>({ url: url, method: 'POST', body: body, headers: headers });
  }

  /**
   * 延迟工具函数
   */
  private static delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
