#! /usr/bin/env python
# cython: language_level=3
# distutils: language=c++

""" Auto Coding """

import asyncio
from functools                               import cached_property
import os
from pathlib                                 import Path
import time
from typing                                  import Dict
from typing                                  import Optional
from typing                                  import List
from typing                                  import AsyncIterator
from typing                                  import Iterator

import dotenv
from fastapi                                 import FastAPI
from fastapi                                 import File
from fastapi                                 import UploadFile
from fastapi                                 import Response
from fastapi                                 import Request
from fastapi                                 import status
from fastapi.responses                       import StreamingResponse
#from llama_index.agent.llm_compiler          import LLMCompilerAgentWorker
from llama_index.storage.chat_store.redis    import RedisChatStore
from llama_index.embeddings.ollama           import OllamaEmbedding
from llama_index.core                        import set_global_handler
from llama_index.core                        import Document
from llama_index.core                        import SimpleDirectoryReader
from llama_index.core                        import Settings
from llama_index.core                        import StorageContext
from llama_index.core                        import VectorStoreIndex
from llama_index.core                        import SummaryIndex
from llama_index.core                        import DocumentSummaryIndex
from llama_index.core                        import SimpleKeywordTableIndex
from llama_index.core                        import PropertyGraphIndex
from llama_index.core                        import KnowledgeGraphIndex
from llama_index.core.agent                  import ReActAgent
from llama_index.core.agent                  import AgentRunner
from llama_index.core.agent                  import StructuredPlannerAgent
from llama_index.core.agent.function_calling.base import FunctionCallingAgent
from llama_index.core.agent.runner.base      import AgentRunner
from llama_index.core.base.embeddings.base   import BaseEmbedding
from llama_index.core.base.llms.types        import ChatMessage
from llama_index.core.base.llms.types        import MessageRole
from llama_index.core.chat_engine            import SimpleChatEngine
from llama_index.core.chat_engine            import CondensePlusContextChatEngine
from llama_index.core.chat_engine.types      import BaseChatEngine
from llama_index.core.chat_engine.types      import ChatMode
from llama_index.core.chat_engine.types      import StreamingAgentChatResponse
from llama_index.core.chat_engine.types      import AgentChatResponse
from llama_index.core.constants              import DEFAULT_SIMILARITY_TOP_K
from llama_index.core.extractors             import TitleExtractor
from llama_index.core.extractors             import SummaryExtractor
from llama_index.core.extractors             import QuestionsAnsweredExtractor
from llama_index.core.extractors             import KeywordExtractor
from llama_index.core.extractors             import BaseExtractor
from llama_index.core.evaluation             import RelevancyEvaluator
from llama_index.core.graph_stores           import SimpleGraphStore
from llama_index.core.indices.base           import BaseIndex
from llama_index.core.indices.property_graph import DynamicLLMPathExtractor
from llama_index.core.indices.property_graph import ImplicitPathExtractor
from llama_index.core.ingestion              import DocstoreStrategy
from llama_index.core.ingestion              import IngestionCache
from llama_index.core.ingestion              import IngestionPipeline
from llama_index.core.llms.llm               import LLM
from llama_index.core.memory                 import ChatMemoryBuffer
from llama_index.core.memory                 import SimpleComposableMemory
from llama_index.core.memory                 import VectorMemory
from llama_index.core.memory.types           import DEFAULT_CHAT_STORE_KEY
from llama_index.core.memory.types           import BaseMemory
from llama_index.core.memory.types           import BaseChatStoreMemory
from llama_index.core.node_parser            import SentenceSplitter
from llama_index.core.node_parser            import HierarchicalNodeParser
from llama_index.core.node_parser            import get_leaf_nodes
from llama_index.core.node_parser            import get_root_nodes
from llama_index.core.postprocessor          import PrevNextNodePostprocessor
from llama_index.core.postprocessor          import AutoPrevNextNodePostprocessor
from llama_index.core.postprocessor          import SentenceEmbeddingOptimizer
from llama_index.core.postprocessor          import LongContextReorder
from llama_index.core.query_engine           import RetrieverQueryEngine
from llama_index.core.query_engine           import RetrySourceQueryEngine
from llama_index.core.query_engine           import RetryQueryEngine
from llama_index.core.query_engine           import SubQuestionQueryEngine
from llama_index.core.retrievers             import QueryFusionRetriever
from llama_index.core.retrievers             import AutoMergingRetriever
from llama_index.core.storage.chat_store     import BaseChatStore
from llama_index.core.tools                  import QueryEngineTool
from llama_index.core.tools                  import FunctionTool
from llama_index.core.tools.types            import ToolMetadata
from llama_index.core.tools.types            import AsyncBaseTool
from llama_index.core.tools.types            import BaseTool
#from llama_index.extractors.entity           import EntityExtractor
from llama_index.llms.ollama                 import Ollama
from llama_index.multi_modal_llms.ollama     import OllamaMultiModal
from llama_index.node_parser.topic           import TopicNodeParser
from llama_index.readers.database            import DatabaseReader
#from llama_index.retrievers.bm25             import BM25Retriever
from llama_index.storage.docstore.redis      import RedisDocumentStore
from llama_index.storage.index_store.redis   import RedisIndexStore
from llama_index.storage.kvstore.redis       import RedisKVStore as RedisCache
from llama_index.vector_stores.redis         import RedisVectorStore
from ollama                                  import AsyncClient
from ollama                                  import Client
from ollama                                  import pull
from redis                                   import Redis
import redis.asyncio as aioredis
from redisvl.schema                          import IndexSchema
from structlog                               import get_logger

from ia_sisyphus.main                        import SisyphusConfig
from ia_spydir.main                          import SPyDirConfig

logger            = get_logger()

class CodeineConfig():

	def __init__(
		self,
		spydir  :SPyDirConfig,
		sisyphus:SisyphusConfig,
	)->None:
		super().__init__()
		self.memories           :Dict[str,BaseMemory] = {}
		self.verbose            :bool                 = True

		self.base_url           :str                  = 'http://192.168.2.249:11434'
		self.chat_model         :str                  = 'llama3.2'
		self.chat_memory_model  :str                  = 'llama3.2'
		self.request_timeout    :int                  = (60 * 30) # 30 minutes

		#self.token_limit       :int                  = 
		self.redis_host         :str                  = '192.168.2.249'
		self.redis_port         :int                  = 6379
		self.ttl                :int                  = self.request_timeout

		self.embed_url          :str                  = self.base_url
		self.embed_name         :str                  = 'nomic-embed-text'
		self.dims               :int                  = 768

		self.similarity_top_k   :int                  = DEFAULT_SIMILARITY_TOP_K

		self.spydir             :SPyDirConfig         = spydir
		self.sisyphus           :SisyphusConfig       = sisyphus

	@property
	def redis_url(self,)->str:
		return str(f'redis://{self.redis_host}:{self.redis_port}')

	@cached_property
	def redis_client(self,)->Redis:
		return Redis.from_url(self.redis_url,)

	#@cached_property
	#def async_redis_client(self,): # TODO
	#	return aioredis.from_url(self.url,)

	@cached_property
	def chat_llm(self,)->LLM:
		return Ollama(
			base_url       =self.base_url,
			model          =self.chat_model,
			request_timeout=self.request_timeout,
			use_json       =False,
			verbose        =self.verbose,)

	@cached_property
	def chat_memory_llm(self,)->LLM:
		return Ollama(
			base_url       =self.base_url,
			model          =self.chat_memory_model,
			request_timeout=self.request_timeout,
			use_json       =False,
			verbose        =self.verbose,)

	@cached_property
	def chat_store(self,)->BaseChatStore:
		return RedisChatStore(
			redis_url=self.redis_url,
			redis_client=self.redis_client,
			#aredis_client=self.async_redis_client,
			#aredis_client=self.aredis_client, # TODO
			ttl      =self.ttl,)

	@property
	def chat_store_key(self,)->str:
		return str(f'{DEFAULT_CHAT_STORE_KEY} ({self.namespace})')

	@cached_property
	def primary_memory(self,)->BaseMemory:
		return ChatMemoryBuffer.from_defaults(
			llm=self.chat_memory_llm,
			chat_store=self.chat_store, )

	@property
	def secondary_memory_sources(self,)->List[BaseMemory]:
		return list(self.memories.values())
		
	@property
	def memory(self,)->BaseMemory:
		primary_memory           :BaseMemory           = self.primary_memory
		secondary_memory_sources :List[BaseMemory]     = self.secondary_memory_sources
		return SimpleComposableMemory.from_defaults(
			primary_memory          =primary_memory,
			secondary_memory_sources=secondary_memory_sources, )

	@property
	def namespace(self,)->str:
		return 'Codeine'

	@property
	def collection(self,)->str:
		return self.namespace

	@property
	def prefix(self,)->str:
		return self.namespace

	@cached_property
	def docstore(self,) -> RedisDocumentStore:
		return RedisDocumentStore.from_redis_client(
			redis_client=self.redis_client,
			namespace   =self.namespace,)

	@cached_property
	def index_store(self,) -> RedisIndexStore:
		return RedisIndexStore.from_redis_client(
			redis_client      =self.redis_client,
			namespace         =self.namespace,
			#collection_suffix=
		)

	@property
	def index_schema_name(self,)->str:
		return str(f'{self.namespace} (vector_store)')

	@cached_property
	def custom_schema(self,) -> IndexSchema:
		return IndexSchema.from_dict({
			'index': {'name': self.index_schema_name, 'prefix': self.prefix, },
			'fields': [
				{'type': 'tag',  'name': 'id', },
				{'type': 'tag',  'name': 'doc_id', },
				{'type': 'text', 'name': 'text', },
				{
					'type': 'vector',
					'name': 'vector',
					'attrs': {
						'dims':            self.dims,
						'algorithm':       'hnsw',
						'distance_metric': 'cosine',
					},
				},
			],
		})

	@cached_property
	def vector_store(self,) -> RedisVectorStore:
		return RedisVectorStore(
			overwrite   =False,
			redis_client=self.redis_client,
			schema      =self.custom_schema,
			store_text  =True,)

	@cached_property
	def storage_context(self,)->StorageContext:
		return StorageContext.from_defaults(
			docstore    =self.docstore,
			index_store =self.index_store,
			vector_store=self.vector_store,
			# TODO
			# graph_store=
			# image_store=
		)
		
	@cached_property
	def embed_model(self,)->BaseEmbedding:
		return OllamaEmbedding(
			base_url=self.embed_url,
			embed_batch_size=1,
			model_name=self.embed_name,
			request_timeout=self.request_timeout,
			verbose=self.verbose,)

	#@cached_property
	#def index(self,)->BaseIndex:
	#	return VectorStoreIndex.from_documents(
	#		[],
	#		storage_context  =self.storage_context,
	#		show_progress    =self.verbose,
	#		#transformations =self.transformations,
	#    		embed_model      =self.embed_model,
	#    		insert_batch_size=1, )

	#@cached_property
	#def retriever(self,)->BaseRetriever:
	#	return self.index.as_retriever(
	#		similarity_top_k=self.similarity_top_k,)
	
	#@cached_property
	#def engine(self,)->BaseChatEngine:
	#	# TODO node postprocessors
	#	# TODO graph
	#	return CondensePlusContextChatEngine.from_defaults(
	#		retriever=self.retriever,
	#		llm      =self.chat_llm,
	#		memory   =self.memory, )

	@property
	def tools(self,)->List[BaseTool]:
		return [
			self.spydir  .query_engine_tool,
			self.sisyphus.query_engine_tool,
		]

	@cached_property
	def agent(self,)->AgentRunner:
		return FunctionCallingAgent.from_tools(
			tools          =self.tools,
			llm            =self.chat_llm,
			memory         =self.memory,
			#tool_retriever=,
			#max_function_calls=DEFAULT_MAX_FUNCTION_CALLS,
			#system_prompt =,
			verbose        =self.verbose, )

	def chat(self, message:str,)->AgentChatResponse:
		return self.agent.chat(message,)

def main()->None:
	dotenv.load_dotenv()
	set_global_handler('simple')

	srcdir         :Path            = Path()
	logger.info('srcdir          : %s', srcdir,)

	spydir         :SPyDirConfig    = SPyDirConfig(
		srcdir=srcdir, )

	dbhost         :str             =     os.getenv ('PGHOST',      '192.168.2.249')
	dbport         :int             = int(os.getenv ('PGPORT',      '5434'))
	dbuser         :str             =     os.getenv ('PGUSER',      'rsyslog')
	dbpassword     :str             =     os.environ['PGPASSWORD']
	dbname         :str             =     os.getenv ('DBNAME',      'Syslog')
	from_host      :str             = str(f'{srcdir.resolve().name}.innovanon.com')
	logger.info('db host         : %s', dbhost,)
	logger.info('db port         : %s', dbport,)
	logger.info('db user         : %s', dbuser,)
	#logger.debug('db password     : %s', dbpassword,)
	logger.info('db name         : %s', dbname,)
	logger.info('from host       : %s', from_host,)

	sisyphus       :SisyphusConfig  = SisyphusConfig(
		dbhost    =dbhost,
		dbport    =dbport,
		dbuser    =dbuser,
		dbpassword=dbpassword,
		dbname    =dbname,
		from_host =from_host, )

	config         :CodeineConfig   = CodeineConfig(
		spydir  =spydir,
		sisyphus=sisyphus, )

	while True:
		message       :str                = input('User: ')
		result        :AgentChatResponse  = config.chat(message=message,)
		print('Agent:', result,)

if __name__ == '__main__':
	main()

__author__:str = 'you.com' # NOQA