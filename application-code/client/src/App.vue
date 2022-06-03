<!-- Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

<template>
  <div id="app">
    <Nav v-if="$route.name!='Login'"/>
    <router-view> </router-view>
    <Footer />
  </div>
</template>

<script>
import Nav from "./components/Nav.vue";

export default {
  name: "app",
  components: {
    Nav,
  },
};
</script>

<style>


#app {
  width: 100%;
  height: 100vh;
  margin: auto;
  font-size: 20px;
  padding: 20px;
  background-color: grey;
  font-family: "Avenir", Helvetica, Arial, sans-serif;
  background-size: cover;
  overflow: scroll;
  padding-top: 3%;
}
.main {
  width: 100%;
  height: 100%;
  background-color: grey;
}
.container {
  width: auto;
  margin: 50px;
  box-sizing: border-box;
  font-size: 15px;
  padding: 60px;
  height: auto;
  overflow: hidden;
  margin: auto;
  font-family: "Avenir", Helvetica, Arial, sans-serif;
  height: auto;
  background-size: cover;
}

.form-group {
  font-family: "Avenir", Helvetica, Arial, sans-serif;
  box-sizing: border-box;
  width: 100%;
  padding: 30px;
  border-radius: 10px;
  background: white;
  font-size: 18px;
  height: auto;
  box-shadow: 5px 5px 5px 5px rgba(0.5, 0.5, 0.5, 0.24),
    5px 5px 5px 5px rgba(0.5, 0.5, 0.5, 0.24);
  border-radius: 20px;
}

h1 {
  text-shadow: gray;
  font-family: "Avenir", Helvetica, Arial, sans-serif;
  color: black;
}
h2 {
  text-shadow: gray;
  color: black;
  font-family: "Avenir", Helvetica, Arial, sans-serif;
}

.button {
  position: absolute;
  width: 100%;
  left: 0;
  text-align: center;
  margin: auto;
  position: relative; top: 50%; transform: translateY(-50%) translateX(30%); width: 100%;
}
.b-navbar {
  margin: 50px;
  box-sizing: border-box;
  font-size: 80px;
  padding: 100px;
  width: auto;
  height: auto;
  overflow: hidden;
  max-width: 580px;
  margin: auto;
  border-radius: 40px;
}
.card {
  width: auto;
  justify-content: center;
  position: relative;
  background-attachment: fixed;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  overflow: hidden;
  box-shadow: 5px 5px 5px 0 rgba(0.5, 0.5, 0.5, 0.5),
    0 5px 5px 0 rgba(0, 0, 0, 0.24);
}

#login {
  font-family: "Avenir", Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
  height: auto;
  overflow: hidden;
}
.login-page {
  width: 360px;
  padding: 8% 0 0;
  margin: auto;
  text-align: center;
  margin-top: 1%;
}
.form {
  position: relative;
  background: #ffffff;
  margin: 0 auto 100px;
  padding: 45px;
  text-align: center;
  box-shadow: 5px 5px 5px 5px rgba(0.5, 0.5, 0.5, 0.24),
    5px 5px 5px 5px rgba(0.5, 0.5, 0.5, 0.24);
  border-radius: 20px;
}
.form input {
  font-family: "Avenir", sans-serif;
  outline: 0;
  background: #f2f2f2;
  width: 100%;
  border: 0;
  margin: 0 0 15px;
  padding: 15px;
  box-sizing: border-box;
  font-size: 14px;
}
.form button {
  font-family: "Avenir", sans-serif;
  text-transform: uppercase;
  outline: 0;
  background: rgb(34, 60, 179);
  width: 100%;
  border: 0;
  padding: 15px;
  color: #ffffff;
  font-size: 14px;
  cursor: pointer;
}
.form button:hover,
.form button:active,
.form button:focus {
  background: rgb(10, 188, 219);
}
#navbar {
  width: auto;
  box-sizing: border-box;
  padding: 0;
  height: auto;
  overflow: hidden;
  font-family: "Avenir", Helvetica, Arial, sans-serif;
  background-size: cover;
}

</style>
