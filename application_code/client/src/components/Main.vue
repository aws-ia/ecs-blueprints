<!-- Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

<template>
  <div class="container">
    <h1>Welcome to the Demo website!</h1>
    <h3>Are you ready to learn how to build a full stack application with Amazon ECS, combining it with DevOps practices?</h3>
    <br>

    <div class="jumbotron text-center winter">
        <h1>Examples of retrieved Items from Amazon Dynamodb + files from Amazon S3!</h1>
    </div>

    <div class="container">
        <div class="row">
            <div class="card-deck inner">
                <div class="card align-items-center">
                    <img class="card-img-top adjustFit" v-bind:src=products[2].path alt="Card image cap">
                        <div class="card-body align-center">
                            <h5 class="card-title cardTextAlignment">{{products[2].title}}</h5>
                        </div>
                        <div class="card-footer">
                            <a class="btn btn-secondary" href="#">Just a button</a>
                        </div>
                </div>
                <div class="card align-items-center">
                    <img class="card-img-top adjustFit" v-bind:src=products[1].path alt="Card image cap">
                        <div class="card-body align-center">
                            <h5 class="card-title cardTextAlignment">{{products[1].title}}</h5>
                        </div>
                        <div class="card-footer">
                            <a class="btn btn-secondary" href="#">Just a button</a>
                        </div>
                </div>
                <div class="card align-items-center">
                    <img class="card-img-top adjustFit" v-bind:src=products[0].path alt="Card image cap">
                        <div class="card-body align-center">
                            <h5 class="card-title cardTextAlignment">{{products[0].title}}</h5>
                        </div>
                        <div class="card-footer">
                            <a class="btn btn-secondary" href="#">Just a button</a>
                        </div>
                </div>
            </div>
            <br>
            <br>
            <div class="card-deck inner">
                <div class="card align-items-center">
                    <img class="card-img-top adjustFit" v-bind:src=products[2].path alt="Card image cap">
                        <div class="card-body align-center">
                            <h5 class="card-title cardTextAlignment">{{products[2].title}}</h5>
                        </div>
                        <div class="card-footer">
                            <a class="btn btn-secondary" href="#">Just a button</a>
                        </div>
                </div>
                <div class="card align-items-center">
                    <img class="card-img-top adjustFit" v-bind:src=products[1].path alt="Card image cap">
                        <div class="card-body align-center">
                            <h5 class="card-title cardTextAlignment">{{products[1].title}}</h5>
                        </div>
                        <div class="card-footer">
                            <a class="btn btn-secondary" href="#">Just a button</a>
                        </div>
                </div>
                <div class="card align-items-center">
                    <img class="card-img-top adjustFit" v-bind:src=products[0].path alt="Card image cap">
                        <div class="card-body align-center">
                            <h5 class="card-title cardTextAlignment">{{products[0].title}}</h5>
                        </div>
                        <div class="card-footer">
                            <a class="btn btn-secondary" href="#">Just a button</a>
                        </div>
                </div>
            </div>

        </div>
    </div>
  </div>

</template>

<script>
import RestServices from "@/services/RestServices";
export default {
  name: "Main",
  data() {
    return {
      products: "",
    }
  },
  created() {
    RestServices.getAllProducts()
        .then((response) => {
            this.products = response.data.products;
        })
        .catch((error) => console.log(error));
  }
};
</script>

<style scoped>

h1 {
  text-shadow: gray;
  font-family: "Avenir", Helvetica, Arial, sans-serif;
  color: white;
  text-align: center;
}

h3 {
  text-shadow: gray;
  font-family: "Avenir", Helvetica, Arial, sans-serif;
  color: white;
  text-align: center;
}

.jumbotron {
    background:orange;
    color: white;
    text-align: center;
}

.card-footer {
	text-align: center;
}

.adjustFit {
    width: 100%;
    height: 20vw;
    object-fit: cover;
}

</style>
