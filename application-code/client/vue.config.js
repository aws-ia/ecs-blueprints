module.exports = {
    publicPath: '/',
    chainWebpack: config => {
      config.module.rules.delete('eslint');
    },
    devServer: {
      port: 3000,
      disableHostCheck: true
    }
  }
