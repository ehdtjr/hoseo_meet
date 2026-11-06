## 인증 갱신 회귀 테스트 (#20)

```sh
corepack yarn install --frozen-lockfile
corepack yarn test
corepack yarn build
```

로그인·갱신은 인증 재시도 interceptor가 없는 `authClient`로 전송합니다.
관리자 API의 동시 401은 세션별로 진행 중인 갱신 하나를 공유하며, 원 요청은
최대 한 번 재전송합니다. 갱신 이후 늦게 도착한 401은 새 토큰을 사용합니다.

- 갱신 400/401: 토큰을 삭제하고 `/login`으로 한 번 이동합니다.
- 갱신 네트워크 오류·5xx: 요청을 실패로 반환하되 토큰과 화면을 유지합니다.
  이후 사용자 동작에서 다시 갱신할 수 있습니다.
- 로그아웃·새 로그인: 이전 세션의 갱신 결과와 요청 재전송을 무시합니다.

Vitest는 실제 Axios interceptor와 transport 대역으로 재귀·병렬 처리·실패 정책을
검증하고, jsdom에서 로그인·보호 라우트·화면 전환을 검증합니다.
실제 브라우저와 백엔드를 연결하는 E2E 검증은 별도입니다.

# React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Babel](https://babeljs.io/) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## Expanding the ESLint configuration

If you are developing a production application, we recommend updating the configuration to enable type-aware lint rules:

```js
export default tseslint.config({
  extends: [
    // Remove ...tseslint.configs.recommended and replace with this
    ...tseslint.configs.recommendedTypeChecked,
    // Alternatively, use this for stricter rules
    ...tseslint.configs.strictTypeChecked,
    // Optionally, add this for stylistic rules
    ...tseslint.configs.stylisticTypeChecked,
  ],
  languageOptions: {
    // other options...
    parserOptions: {
      project: ['./tsconfig.node.json', './tsconfig.app.json'],
      tsconfigRootDir: import.meta.dirname,
    },
  },
})
```

You can also install [eslint-plugin-react-x](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-x) and [eslint-plugin-react-dom](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-dom) for React-specific lint rules:

```js
// eslint.config.js
import reactX from 'eslint-plugin-react-x'
import reactDom from 'eslint-plugin-react-dom'

export default tseslint.config({
  plugins: {
    // Add the react-x and react-dom plugins
    'react-x': reactX,
    'react-dom': reactDom,
  },
  rules: {
    // other rules...
    // Enable its recommended typescript rules
    ...reactX.configs['recommended-typescript'].rules,
    ...reactDom.configs.recommended.rules,
  },
})
```
