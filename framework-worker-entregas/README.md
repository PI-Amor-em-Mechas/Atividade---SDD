# React + Vite

Este template fornece uma configuração mínima para executar uma aplicação React com Vite, incluindo HMR (Hot Module Replacement) e algumas regras do Oxlint.

Atualmente, estão disponíveis dois plugins oficiais:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) utiliza [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) utiliza [SWC](https://swc.rs/)

## React Compiler

O React Compiler não está habilitado neste template devido ao impacto que pode causar no desempenho durante o desenvolvimento e o processo de build.

Para habilitá-lo, consulte a documentação oficial:

https://react.dev/learn/react-compiler/installation

## Expandindo a configuração do Oxlint

Caso esteja desenvolvendo uma aplicação para produção, é recomendado utilizar TypeScript com regras de lint que considerem informações de tipos.

Consulte o template TypeScript do Vite para obter informações sobre como integrar TypeScript e as regras relacionadas do Oxlint:

https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react-ts