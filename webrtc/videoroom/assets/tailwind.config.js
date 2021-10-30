module.exports = {
    mode: 'jit',
    purge: {
        content: [
          './js/**/*.js',
          '../lib/*_web/**/*.*ex'
        ],
        safelist: ['grid', 'grid-cols-1', 'grid-cols-2', 'grid-cols-3', 'grid-cols-4']
    },
    theme: {
    },
    variants: {
      extend: {},
    },
    plugins: [],
  }