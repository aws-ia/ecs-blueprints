<!-- Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

<template>
  <div id="login">
    <div class="form">
      <h1>AWS Demo Login*</h1>
      <form @submit.prevent="onSubmit">
        <input
          v-model="user"
          type="text"
          placeholder="Username"
        />
        <input
          v-model="password"
          type="password"
          placeholder="Password"
        />
        <button
          value="Submit"
          type="submit"
          style="background-color: orange; color: white ; border-radius: 5px;"
          :disabled="disabledButton"
        >Login
        </button>
      </form>
      <br>
      <h5>*No auth was implemented, just a Vue.js demo component</h5>
    </div>
  </div>
</template>

<script>
import RestServices from "@/services/RestServices";

export default {
  name: "Login",
  data() {
    return {
      disabledButton: false,
      user: "",
      password: "",
    };
  },
  methods: {
    async onSubmit() {
      this.disabledButton = true;
      this.$router.push("main");
    }
  }
};
</script>
<style scoped>

#login {
  padding-top: 10%;
}

.form {
  max-width: 360px;
}

</style>
