from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth
import boto3
from sentence_transformers import SentenceTransformer
import os
import sys

module_path = "./"
sys.path.append(os.path.abspath(module_path))

def get_parameter(name):
    ssm = boto3.client('ssm')
    param = ssm.get_parameter(Name=name,WithDecryption=True)
    return param['Parameter']['Value']

# Load the SentenceTransformer model
model_name = 'sentence-transformers/msmarco-distilbert-base-tas-b'
model = SentenceTransformer(model_name)

# Set the desired vector size
vector_size = 768

# OpenSearch Information
opensearch_endpoint = get_parameter("aoss_endpoint")
host = opensearch_endpoint.replace("https://", "")
region = get_parameter("aoss_region")

service = 'aoss'
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(region=region, service=service,refreshable_credentials=credentials)

# Create an OpenSearch client
client = OpenSearch(
    hosts = [{'host': host, 'port': 443}],
    http_auth = awsauth,
    timeout = 300,
    use_ssl = True,
    verify_certs = True,
    connection_class = RequestsHttpConnection
)

# Define queries for OpenSearch
def query_qna(query, index):
    query_embedding = model.encode(query).tolist()
    query_qna = {
        "size": 5,
        "fields": ["content", "title"],
        "_source": False,
        "query": {
            "knn": {
            "v_content": {
                "vector": query_embedding,
                "k": vector_size
            }
            }
        }
    }

    relevant_documents = client.search(
        body = query_qna,
        index = index
    )
    return relevant_documents

# Search result from OpenSearch
def query_movies(query, sort, genres, rating, size, index):

    sort_type = sort if sort in ['year', 'rating'] else "_score"
    genres = genres if genres else '*'
    rating = rating if rating else 0

    query_embedding = model.encode(query).tolist()

    # semantic search
    query_knn = {
        "size": size,
        "sort": [
            {
                sort_type: {
                    "order": "desc"
                }
            }
        ],
        "_source": {
            "includes": [
                "title",
                "plot",
                "rating",
                "year",
                "poster",
                "genres",
                "actors"
            ]
        },
        "query": {
            "bool": {
                "should": [
                    {
                        "knn": {
                            "v_plot": {
                                "vector": query_embedding,
                                "k": vector_size
                            }
                        }
                    },
                    {
                        "knn": {
                            "v_title": {
                                "vector": query_embedding,
                                "k": vector_size
                            }
                        }
                    }
                ],
                "filter": [
                    {
                        "query_string": {
                            "query": genres,
                            "fields": [
                                "genres"
                            ]
                        }
                    },
                    {
                      "range": {
                        "rating": {
                          "gte": rating
                        }
                      }
                    }
                ]
            }
        }
    }

    response_knn = client.search(body = query_knn, index = index)

    # Extract relevant information from the search result
    hits_knn = response_knn['hits']['hits']
    doc_count_knn = response_knn['hits']['total']['value']
    results_knn = [{'genres':  hit['_source']['genres'],'poster':  hit['_source']['poster'],'title': hit['_source']['title'], 'rating': hit['_source']['rating'], 'year': hit['_source']['year'], 'plot' : hit['_source']['plot'], 'actor' : hit['_source']['actors']} for hit in hits_knn]

    # lexical search
    query_kw = {
        "size": size,
        "sort": [
            {
                sort_type: {
                    "order": "desc"
                }
            }
        ],
        "_source": {
            "includes": [
                "title",
                "plot",
                "rating",
                "year",
                "poster",
                "genres",
                "actors"
            ]
        },
        "query": {
            "bool": {
                "must": {
                    "multi_match": {
                        "query": query,
                        "fields": ["plot", "title"]
                    }
                },
                "filter": [
                    {
                        "query_string": {
                            "query": genres,
                            "fields": [
                                "genres"
                            ]
                        }
                    },
                    {
                      "range": {
                        "rating": {
                          "gte": rating
                        }
                      }
                    }
                ]
            }
        }
    }

    response_kw = client.search(body = query_kw, index = index)

    # Extract relevant information from the search result
    hits_kw = response_kw['hits']['hits']
    doc_count_kw = response_kw['hits']['total']['value']
    results_kw = [{'genres':  hit['_source']['genres'],'poster':  hit['_source']['poster'],'title': hit['_source']['title'], 'rating': hit['_source']['rating'], 'year': hit['_source']['year'], 'plot' : hit['_source']['plot'], 'actor' : hit['_source']['actors']} for hit in hits_kw]



    return results_knn, doc_count_knn, results_kw, doc_count_kw
