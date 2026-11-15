# Projeto: Dinâmica Imobiliária de São Paulo — 1996 a 2025

> **Origem:** resumo elaborado no ChatGPT, enviado pelo Guilherme em 2026-11-15. O texto abaixo está reproduzido sem alterações de conteúdo (só a formatação foi convertida para Markdown). As divergências em relação aos dados verificados e às decisões posteriores estão no fim, em "Notas de conferência".

Resumo de contexto, objetivos, bases de dados e agenda de pesquisa

## 1. Objetivo geral

Desenvolver um ambiente de pesquisa e análise quantitativa do mercado imobiliário da cidade de São Paulo, utilizando bases históricas de IPTU e ITBI, complementadas por informações geográficas, urbanísticas, econômicas e bibliográficas.

O objetivo é reconstruir a dinâmica imobiliária da cidade ao longo de aproximadamente três décadas, investigando a evolução do estoque, a produção de novas unidades, os preços, a transformação física das quadras, os efeitos de políticas públicas e a influência de mudanças macroeconômicas e de infraestrutura.

Trata-se de um projeto de pesquisa e geração de insights pessoais, com possibilidade de produzir ferramentas de análise espacial e displays interativos em etapas futuras.

## 2. Bases de dados disponíveis

### IPTU — 1996 a 2025

Base cadastral anual de todos os imóveis do município de São Paulo, contendo, entre outras informações:

- Número de contribuinte/inscrição imobiliária.
- Área do terreno e área construída.
- Comprimento da frente (testada).
- CEP e endereço.
- Valor venal do imóvel.
- Valor venal do terreno.
- Tipo de imóvel: residencial vertical, residencial horizontal, terreno, comercial, varejo etc.
- Padrão construtivo e demais características cadastrais.

Uma característica particularmente importante é a possibilidade de observar a transformação dos imóveis dentro de cada quadra ao longo do tempo.

É possível identificar indícios de fusão de lotes, alterações cadastrais, desaparecimento de inscrições e posterior formação de conjuntos de unidades pertencentes a um mesmo condomínio. Essa sequência pode permitir reconstruir parcialmente o processo de incorporação imobiliária.

### ITBI — 1999 a 2025

Base de transações imobiliárias da cidade de São Paulo, contendo:

- Número de IPTU associado à transação.
- Valor declarado pelo comprador.
- Valor venal utilizado pela Prefeitura.
- Data da transação.
- Demais informações disponíveis no cadastro.

A possibilidade de cruzamento pelo número de IPTU permite relacionar as transações às características físicas e cadastrais dos imóveis.

Embora a base seja mensal, a periodicidade principal das análises será anual.

### Bases geográficas e urbanísticas

Já estão disponíveis ou serão disponibilizados:

- Arquivo KMZ com os polígonos das quadras.
- Arquivo KMZ com os polígonos dos CEPs.
- Mapa de lotes, referente a uma data específica.
- Mapa de zoneamento e parâmetros urbanísticos, incluindo as alterações associadas ao Plano Diretor de 2014.

O georreferenciamento no nível do lote poderá ser desenvolvido posteriormente, especialmente para estudos detalhados de regiões específicas.

### Outras fontes

O projeto poderá incorporar progressivamente outras bases de dados, séries econômicas, informações públicas e fontes externas.

Também serão feitos uploads de artigos acadêmicos, livros, estudos, relatórios e outros materiais bibliográficos. Esses documentos deverão integrar o repertório de referência para a formulação de hipóteses, discussão metodológica e interpretação dos resultados.

## 3. Unidade espacial e temporal

**Unidade espacial principal: quadra.**

A quadra será a unidade central de análise porque apresenta estabilidade espacial e, em princípio, mantém os mesmos parâmetros de zoneamento ao longo do tempo.

Quando pertinente, poderá ser utilizada a combinação quadra × CEP.

O lote será uma unidade complementar, utilizada principalmente em estudos localizados. A intenção é observar fenômenos como:

- Fusão de terrenos.
- Consolidação de propriedades.
- Formação de terrenos para incorporação.
- Transformação de terrenos em empreendimentos verticais.
- Formação de condomínios e multiplicação de inscrições imobiliárias.

Entretanto, não se pretende inicialmente realizar o acompanhamento individual de todos os lotes ao longo de toda a série histórica.

**Unidade temporal: ano.**

O IPTU já possui periodicidade anual. O ITBI, embora mensal, será inicialmente agregado por ano.

As análises poderão contemplar tanto a dinâmica recente quanto comparações entre períodos distantes, especialmente para investigar mudanças de regime econômico, urbanístico e imobiliário.

**Deflação:** os valores monetários serão sempre convertidos para valores reais utilizando o IPCA. A série histórica será fornecida por link.

## 4. Agenda de pesquisa — hipóteses inicialmente propostas

Os itens abaixo representam as possibilidades de investigação apresentadas inicialmente pelo responsável pelo projeto. Não constituem uma lista fechada nem pressupõem que todas as hipóteses já estejam metodologicamente definidas.

### 4.1. Oferta, estoque e renovação imobiliária

- Percentual de unidades novas em relação ao estoque imobiliário existente.
- Evolução da participação de unidades novas no estoque total.
- Dinâmica de renovação do estoque imobiliário.
- Comparação entre lançamentos e estoque existente.

### 4.2. Preços e características dos empreendimentos

- Variação dos preços de grandes edifícios e seu impacto sobre os indicadores agregados do mercado.
- Diferença de preços entre imóveis premium e a média do mercado.
- Diferença de preços entre unidades de empreendimentos com piscina e academia e a média do mercado.
- Comparação entre preços de lançamentos e preços médios dos ativos existentes no estoque.

### 4.3. Crédito e financiamento à construção

- Efeito da oferta de crédito sobre o financiamento à construção.
- Relação temporal entre disponibilidade de crédito, produção imobiliária, lançamentos e preços.
- Investigação do efeito da expansão ou contração do crédito sobre a oferta de novas unidades.

### 4.4. Custos de construção

- Efeito do aumento do preço dos insumos de construção, com atenção especial ao movimento observado em 2012.
- Investigação dos efeitos sobre preços, lançamentos, oferta e atividade imobiliária.

### 4.5. Distratos

- Efeito dos distratos observados em 2015 sobre o mercado imobiliário.
- Possíveis consequências sobre oferta, preços, estoque disponível e comportamento dos incorporadores.

### 4.6. Plano Diretor de 2014 e mudanças urbanísticas

- Efeito dos incentivos do Plano Diretor de 2014 sobre os preços dos terrenos.
- Investigação das áreas que tiveram aumento do potencial construtivo em comparação com áreas que não receberam os mesmos incentivos.
- Efeito da alteração do coeficiente de aproveitamento sobre o valor econômico dos terrenos.
- Efeito líquido da política urbanística: democratização do acesso à cidade versus gentrificação.
- Investigação dos efeitos do Plano Diretor sobre o financiamento e a viabilidade econômica da construção.

### 4.7. Infraestrutura de transporte

- Efeito da inauguração de novas estações de metrô sobre os preços dos imóveis.
- Investigação das alterações na dinâmica imobiliária das quadras localizadas no entorno das estações.
- Possíveis efeitos sobre verticalização, oferta, perfil dos empreendimentos e valorização dos terrenos.

### 4.8. Valores declarados nas transações

- Comparação entre o valor declarado pelo comprador no ITBI e o valor venal utilizado pela Prefeitura.
- Investigação das diferenças entre os valores declarados e os valores de referência.
- Análise da evolução temporal dessas diferenças e de sua distribuição espacial.

O objetivo é investigar o comportamento das partes nas declarações de valores das transações, identificando padrões de subdeclaração ou outras discrepâncias sistemáticas.

## 5. Possibilidades adicionais de pesquisa identificadas na discussão

Os itens seguintes foram sugeridos durante a elaboração inicial do projeto. São possibilidades complementares, ainda não aprovadas como agenda definitiva.

### Transformação física e dinâmica das quadras

- Identificação de fusões de lotes e consolidação de terrenos.
- Identificação de possíveis processos de land banking e preparação de terrenos para incorporação.
- Identificação de transformações cadastrais que antecedem a construção de empreendimentos.
- Detecção de mudanças de uso e padrão construtivo, especialmente de terrenos e imóveis horizontais para empreendimentos verticais.
- Investigação da relação temporal entre consolidação de terrenos, incorporação, formação de condomínios e comercialização das unidades.

### Verticalização e composição do estoque

- Evolução do grau de verticalização das quadras.
- Relação entre número de unidades, área construída e quantidade de inscrições imobiliárias.
- Identificação de quadras com mudanças expressivas na composição do estoque.
- Investigação da contribuição de grandes empreendimentos para a evolução dos preços médios locais.

### Dinâmica de preços e atributos imobiliários

- Relação entre atributos físicos dos imóveis e preços de transação.
- Investigação da influência de área, testada, localização e características construtivas sobre os valores.
- Comparação entre preços de terrenos e preços de imóveis construídos.
- Análise da dispersão dos preços dentro de uma mesma quadra.
- Investigação da evolução dos diferenciais de preço entre segmentos e padrões construtivos.

### Dinâmica espacial e diferenças socioeconômicas

- Comparação entre bairros de renda elevada e bairros de renda mais baixa.
- Investigação da distribuição espacial dos novos empreendimentos.
- Análise de mudanças no perfil imobiliário das regiões.
- Investigação dos efeitos distributivos das transformações urbanas.

### Análise econométrica e causal

- Modelos de painel com efeitos fixos de quadra e ano.
- Diferenças-em-diferenças para investigar efeitos de mudanças urbanísticas e inaugurações de infraestrutura.
- Comparações entre grupos tratados e grupos de controle.
- Investigação de efeitos heterogêneos conforme localização, renda, padrão construtivo e características das quadras.

Essas possibilidades são sugestões metodológicas e analíticas, não resultados ou conclusões antecipadas.

## 6. Diretrizes metodológicas

A abordagem deverá partir de análises descritivas e exploratórias, avançando progressivamente para modelos econométricos e inferências causais.

Cada hipótese exigirá a identificação de suas próprias variáveis, restrições, grupos de comparação, recortes espaciais e janelas temporais.

Não se deve pressupor que uma única metodologia seja adequada a todas as perguntas.

Um princípio importante será identificar e explorar as variações espaciais e temporais que permitam isolar efeitos específicos.

Exemplos:

- Áreas que receberam incentivos urbanísticos versus áreas que não receberam.
- Quadras próximas a novas estações de metrô versus quadras comparáveis mais distantes.
- Bairros de renda elevada versus bairros de renda mais baixa.
- Períodos anteriores e posteriores a mudanças regulatórias ou econômicas.

As métricas e os modelos deverão ser construídos em conjunto, à medida que as bases forem compreendidas e as hipóteses forem amadurecendo.

## 7. Ambiente de desenvolvimento

O projeto será desenvolvido em Python.

O responsável pelo projeto possui experiência significativa em R, mas menor familiaridade com Python. Portanto, o desenvolvimento deverá ser realizado de maneira incremental, com programação, execução e teste de cada bloco de código em conjunto.

Preferências técnicas já estabelecidas:

- Python como linguagem principal.
- Parquet como formato de armazenamento.
- PyArrow como biblioteca preferencial para leitura, escrita e manipulação dos arquivos Parquet.
- Desenvolvimento modular, evitando concentrar todo o trabalho em um único script ou notebook.
- Utilização de bibliotecas adicionais quando justificadas pelas necessidades analíticas.
- Geoprocessamento quando necessário, especialmente para cruzamentos espaciais e análises de entorno.

A intenção futura é desenvolver um display acessível online, possivelmente com acesso restrito e inicialmente limitado a regiões específicas da cidade.

Essa etapa está distante e não deve condicionar prematuramente as decisões atuais de desenvolvimento.

## 8. Natureza e continuidade do projeto

Este será um projeto contínuo de pesquisa, desenvolvido dentro de um Project do ChatGPT.

Além do tratamento dos bancos de dados, o trabalho envolverá:

- Compreensão progressiva das bases e de suas limitações.
- Formulação e refinamento de hipóteses.
- Discussão de mecanismos econômicos e urbanísticos.
- Pesquisa bibliográfica.
- Desenvolvimento de métricas.
- Construção e teste de modelos estatísticos e econométricos.
- Interpretação crítica dos resultados.

O repertório de pesquisa será ampliado continuamente por meio de novos bancos de dados, mapas, artigos, livros e outras fontes.

A lista de perguntas de pesquisa apresentada neste documento é aberta. Novas linhas de investigação poderão surgir à medida que os dados forem explorados e novas relações forem identificadas.

**Objetivo final:** construir uma base empírica robusta para compreender a evolução do mercado imobiliário paulistano, identificar os mecanismos que determinam sua dinâmica e investigar os efeitos econômicos, urbanísticos e distributivos das transformações ocorridas na cidade entre 1996 e 2025.

---

## Notas de conferência (Claude, 2026-11-15)

Pontos em que este resumo diverge do que foi verificado nos dados (`docs/inspecao_2026-11-15.md`) ou do que foi decidido depois (documento de passagem v1.3 e `CLAUDE.md`). O texto acima não foi alterado; cabe ao Guilherme decidir o que prevalece.

1. **Período do IPTU.** O resumo diz 1996–2025; os Parquets cobrem 1995–2025 (31 anos).
2. **Valor venal no IPTU.** O resumo lista "valor venal do imóvel" e "valor venal do terreno". Nos Parquets tratados essas colunas (`VALOR_TOTAL`, `VALOR_TERRENO`, `VALOR_CONSTRUCAO`) estão 100% vazias; existem só o valor do m² do terreno e da construção, com áreas, fração ideal e fator de obsolescência. O valor venal terá de ser calculado (questão Q-02 em `docs/decisoes.md`).
3. **Período do ITBI.** O resumo diz 1999–2025; os Parquets têm partições de 1994 a 2026 (até 07/08/2026), mas a cobertura útil começa em 2006 (antes disso, algumas centenas de guias por ano).
4. **Linguagem (seção 7).** O resumo define Python como linguagem principal. O documento de passagem v1.3, posterior, define R na limpeza e na econometria (revisão linha a linha pelo Guilherme) e Python na infraestrutura (BigQuery). O `CLAUDE.md` segue a versão mais recente; confirmar.
5. **Estabilidade da quadra (seção 3).** O resumo trata a quadra como espacialmente estável. As ressalvas de método do `CLAUDE.md` (item 5) lembram que remembramentos, desapropriações e renumerações mudam o desenho das quadras, o que pede uma tabela de correspondência no tempo.
6. **Armazenamento.** O resumo prevê Parquet com PyArrow; o documento de passagem acrescenta o BigQuery como banco na web (Frente 2). As duas coisas são compatíveis: os Parquets continuam sendo a saída do pipeline e a fonte da carga.
