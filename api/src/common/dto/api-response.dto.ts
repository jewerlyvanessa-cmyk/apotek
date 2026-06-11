export class ApiResponseDto<T = unknown> {
  success: boolean;
  message: string;
  data?: T;
  meta?: Record<string, unknown>;
  errors?: string[];
  code?: string;

  static ok<T>(data: T, message = 'Success', meta?: Record<string, unknown>) {
    return {
      success: true,
      message,
      data,
      meta,
    };
  }

  static fail(message: string, code?: string, errors?: string[]) {
    return {
      success: false,
      message,
      code,
      errors: errors ?? [],
    };
  }
}
