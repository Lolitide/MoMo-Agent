/*
 * ============================================================================
 * 文件名：service/backend/CloudHttpClient.ets
 * ============================================================================
 * 【用途】云服务HTTP客户端，自动添加Token
 * ============================================================================
 */
import { HttpClient, HttpRequestOptions, HttpResponse } from '../ai/HttpClient';
import { TokenManager } from '../auth/TokenManager';
import { Logger } from '../../utils/Logger';

export class CloudHttpClient {
  private static readonly TAG = 'CloudHttpClient';

  /**
   * 发起请求（自动添加Token）
   */
  static async request<T = Object>(options: HttpRequestOptions): Promise<HttpResponse<T>> {
    try {
      // 获取有效的访问Token
      const token = await TokenManager.get().getValidAccessToken();

      // 添加Authorization头
      const newHeaders: Record<string, string> = {};
      newHeaders['Authorization'] = `Bearer ${token}`;
      newHeaders['Content-Type'] = 'application/json';

      if (options.headers) {
        Object.keys(options.headers).forEach(key => {
          newHeaders[key] = options.headers![key];
        });
      }

      options.headers = newHeaders;

      Logger.info(CloudHttpClient.TAG, `请求: ${options.method || 'GET'} ${options.url}`);

      // 调用基础HttpClient
      return await HttpClient.request<T>(options);
    } catch (error) {
      Logger.error(CloudHttpClient.TAG, `请求失败: ${error}`);

      // 如果是401错误，可能是Token过期
      if (error && error.toString().includes('401')) {
        Logger.warn(CloudHttpClient.TAG, 'Token可能已过期，尝试刷新...');
        // TODO: 触发Token刷新逻辑
      }

      throw new Error(`请求失败: ${error}`);
    }
  }

  /**
   * GET请求
   */
  static async get<T = Object>(url: string, headers?: Record<string, string>): Promise<HttpResponse<T>> {
    return CloudHttpClient.request<T>({ url: url, method: 'GET', headers: headers });
  }

  /**
   * POST请求
   */
  static async post<T = Object>(
    url: string,
    body?: string | object,
    headers?: Record<string, string>
  ): Promise<HttpResponse<T>> {
    return CloudHttpClient.request<T>({ url: url, method: 'POST', body: body, headers: headers });
  }

  /**
   * PUT请求
   */
  static async put<T = Object>(
    url: string,
    body?: string | object,
    headers?: Record<string, string>
  ): Promise<HttpResponse<T>> {
    return CloudHttpClient.request<T>({ url: url, method: 'PUT', body: body, headers: headers });
  }

  /**
   * DELETE请求
   */
  static async delete<T = Object>(url: string, headers?: Record<string, string>): Promise<HttpResponse<T>> {
    return CloudHttpClient.request<T>({ url: url, method: 'DELETE', headers: headers });
  }
}
