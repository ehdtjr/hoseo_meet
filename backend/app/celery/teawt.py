import tracemalloc
from optimum.onnxruntime import ORTModelForSequenceClassification
import psutil
import os
import torch

from transformers import AutoTokenizer

sentiment_model = ORTModelForSequenceClassification.from_pretrained("app/celery/ai_moel")
sentiment_tokenizer = AutoTokenizer.from_pretrained("app/celery/ai_moel")

def memory_mb():
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / 1024 / 1024

tracemalloc.start()

print(f"[메모리] 시작 시점: {memory_mb():.2f} MB")
start_snapshot = tracemalloc.take_snapshot()

# ✅ 추론 실행
text = "오늘 날씨 정말 좋다!"
inputs = sentiment_tokenizer(text, return_tensors="pt", truncation=True)
with torch.no_grad():
    outputs = sentiment_model(**inputs)
    probs = torch.softmax(outputs.logits, dim=1)
    pred = torch.argmax(probs, dim=1).item()

print(f"[예측] 결과: {pred}")
print(f"[메모리] 실행 후: {memory_mb():.2f} MB")

end_snapshot = tracemalloc.take_snapshot()
top_stats = end_snapshot.compare_to(start_snapshot, 'lineno')

print("[메모리 diff]")
for stat in top_stats[:10]:
    print(stat)
