// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import Vue from 'vue'
import VueRouter from 'vue-router'
import Router from "vue-router";
import Main from '../components/Main'
import Login from '../components/Login';

Vue.use(Router);

const routes = [
  { path: "*", redirect: "/" },
  { path: '/', name: 'Login', component: Login },
  { path: '/main', name: 'Main', component: Main },
  { path: '/about', name: 'About', component: () => import(/* webpackChunkName: "about" */ '../views/About.vue') },
  { path: '/search', name: 'Search', component: () => import(/* webpackChunkName: "search" */ '../views/EasterEgg.vue') },
]

export const router = new VueRouter({
  mode: "history",
  base: __dirname,
  routes
})

export default router
