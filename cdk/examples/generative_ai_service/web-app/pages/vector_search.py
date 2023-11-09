import streamlit as st
from utils import opensearch
import sys 
import os

module_path = ".."
sys.path.append(os.path.abspath(module_path))

st.set_page_config(
    page_title="vector_search",
    layout="wide",
    page_icon=":technologist:"
)

st.sidebar.header("Search Filters")

st.header('Generative AI Demo - Semantic search using kNN :technologist:')

st.divider() 
question = st.text_input("Enter your search term", "movie for comedy")

# Filters
with st.sidebar.form("Filters"):
    sort_by = st.sidebar.selectbox("Sort By", ["score", "year", "rating"])
    genres_filter = st.sidebar.selectbox("Select Genre", ["*", "Comedy", "Mystery", "Action", "Romance" ])
    size_filter = st.sidebar.slider('Enter number of matched documents', min_value=5, max_value=15, value=10)
    rating_filter = st.sidebar.slider('Enter rating', min_value=0.0, max_value=10.0, value=5.0)
    
if question:
    response_knn, doc_count_knn = opensearch.query_movies(question, sort_by, genres_filter, rating_filter, size_filter, "opensearch_movies")
    print(response_knn)

    st.write(f"Showing **{len(response_knn)} out of {doc_count_knn}** matched documents")
    st.divider()
    
    for i in range(len(response_knn)):
        headings_knn, image_knn = st.columns(2)
        with headings_knn:           
            if i < len(response_knn):
                st.header(response_knn[i]['title'] + " (" +  str(response_knn[i]["year"]) + ")")
                st.write("**" + response_knn[i]["plot"] + "**")
                st.write("**"  + str(response_knn[i]["rating"]) + "** :star2:     " + "**" + str(response_knn[i]["genres"]) + "**")
                st.write(response_knn[i]["actor"])
        with image_knn:
            if i < len(response_knn):
                st.image(response_knn[i]["poster"], caption=response_knn[i]["title"], width=100)    
          