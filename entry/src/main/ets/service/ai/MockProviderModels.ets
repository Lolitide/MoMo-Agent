// MockProvider的类型定义
interface Insight {
  title: string;
  content: string;
}

interface DailySummary {
  summary: string;
  emotion: string;
  theme: string;
  insights: Insight[];
}

interface Scene {
  index: number;
  title: string;
  description: string;
  emotion: string;
}

interface ComicScript {
  title: string;
  scenes: Scene[];
}

interface Updates {
  title: string;
  importance: number;
  tags: string[];
}

interface CorrectionResponse {
  action: string;
  memoryId: string;
  updates: Updates;
  reasoning: string;
}

interface MemoryResponse {
  memoryType: string;
  importance: number;
  tags: string[];
  summary: string;
  relatedMemories: string[];
}

export { Insight, DailySummary, Scene, ComicScript, Updates, CorrectionResponse, MemoryResponse };
