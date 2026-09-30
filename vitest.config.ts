import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['src/webroot/js/**/*.test.ts'],
    environment: 'happy-dom',
    environmentOptions: { happyDOM: { settings: { disableCSSFileLoading: true } } },
    setupFiles: ['./vitest.setup.ts'],
    server: {
      deps: {
        inline: ['@material/material-color-utilities'],
      },
    },
  },
})
