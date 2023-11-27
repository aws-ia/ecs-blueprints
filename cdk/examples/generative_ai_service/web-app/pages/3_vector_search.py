import streamlit as st
from utils import opensearch
import sys
import os

module_path = ".."
sys.path.append(os.path.abspath(module_path))

st.set_page_config(
    page_title="vector search",
    layout="wide",
    page_icon=":technologist:"
)

st.header('Generative AI Demo - Semantic search :technologist:')
st.divider()

question = st.text_input("Enter your search term", "movie for comedy")

# filters
st.sidebar.header("Search Filters")

with st.sidebar.form("Filters"):
    sort_by = st.sidebar.selectbox("Sort By", ["score", "year", "rating"])
    genres_filter = st.sidebar.selectbox("Select Genre", ["*", "Comedy", "Mystery", "Action", "Romance" ])
    size_filter = st.sidebar.slider('Enter number of matched documents', min_value=5, max_value=15, value=10)
    rating_filter = st.sidebar.slider('Enter rating', min_value=0.0, max_value=10.0, value=5.0)

if question:
    response_knn, doc_count_knn, response_kw, doc_count_kw = opensearch.query_movies(question, sort_by, genres_filter, rating_filter, size_filter, "opensearch_movies")

    with st.container():
        knn, kw = st.columns(2)
        with knn:
            st.header('Semantic Search using kNN')
            st.write(f"Showing **{len(response_knn)} out of {doc_count_knn}** matched documents")
            st.divider()
        with kw:
            st.header('Lexical Search using keywords')
            st.write(f"Showing **{len(response_kw)} out of {doc_count_kw}** matched documents")
            st.divider()

    for i in range(max(len(response_knn), len(response_kw))):
        headings_knn, image_knn, headings_kw, image_kw = st.columns(4)
        with headings_knn:
            if i < len(response_knn):
                st.header(response_knn[i]['title'] + " (" +  str(response_knn[i]["year"]) + ")")
                st.write("**" + response_knn[i]["plot"] + "**")
                st.write("**"  + str(response_knn[i]["rating"]) + "** :star2:     " + "**" + str(response_knn[i]["genres"]) + "**")
                st.write(response_knn[i]["actor"])
        with image_knn:
            if i < len(response_knn):
                st.image(response_knn[i]["poster"], caption=response_knn[i]["title"], width=100)
        with headings_kw:
            if i < len(response_kw):
                st.header(response_kw[i]["title"] + " (" +  str(response_kw[i]["year"]) + ")")
                st.write("**" + response_kw[i]["plot"] + "**")
                st.write("**"  + str(response_kw[i]["rating"]) + "** :star2:     " + "**" + str(response_kw[i]["genres"]) + "**")
                st.write(response_knn[i]["actor"])
        with image_kw:
            if i < len(response_kw):
                st.image(response_kw[i]["poster"], caption=response_kw[i]["title"], width=100)
