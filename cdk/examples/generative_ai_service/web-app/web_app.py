import streamlit as st
import os

version = os.environ.get("WEB_VERSION", "0.0")

st.header(f"Generative AI Demo (Version {version})")
st.markdown("Generative AI models' demo with AWS services :computer:")
st.markdown("_Please select an option from the sidebar_")
