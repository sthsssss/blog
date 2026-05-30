# 이미지 업로드 가이드

블로그 포스트에 이미지를 추가하려면:

1. **이미지 저장 위치**: `/public/images/` 폴더에 이미지 파일을 저장합니다.

2. **마크다운에서 사용**:
   ```markdown
   ![설명](/images/filename.png)
   ```

3. **프런트매터에서 사용**:
   ```markdown
   ---
   image:
     url: "/images/filename.png"
     alt: "이미지 설명"
   ---
   ```

## 지원되는 이미지 형식
- PNG (.png)
- JPEG (.jpg, .jpeg)
- WebP (.webp)
- GIF (.gif)

## 예시

### 블로그 포스트 헤더 이미지
포스트의 프런트매터에 다음과 같이 추가하면 됩니다:

```yaml
---
title: "My Post Title"
pubDate: 2024-01-15
description: "Post description"
author: "Your Name"
image:
  url: "/images/post-header.png"
  alt: "Post header description"
tags: ["tag1", "tag2"]
---
```

### 포스트 본문 이미지
마크다운에서 일반적인 이미지 문법을 사용합니다:

```markdown
![설명 텍스트](/images/screenshot.png)
```
