# Labor Market Dynamics and Social Networks: An Agent-Based Model
 
[![NetLogo Version](https://img.shields.io/badge/NetLogo-6.4.0-blue.svg)](https://ccl.northwestern.edu/netlogo/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
 
This repository contains the NetLogo agent-based model (ABM) developed for the Master's thesis: **"The Role of Social Networks in Shaping Wage Outcomes: An Agent-Based Model Analysis Using CGSS Data"**.
 
The model simulates how job seekers find employment and negotiate wages through different social network structures (Random, Small-World, Scale-Free) and formal channels, exploring the impact of network topology on wage inequality and labor market efficiency.
 
## 🧠 Model Overview
 
The model is grounded in Granovetter's "Strength of Weak Ties" theory and labor economics' search and matching theory. It consists of three main agent types:
- **Job Seekers**: Characterized by their skill level, expected wage, social network, and employment status.
- **Firms**: Characterized by their productivity, growth rate, and available job vacancies.
- **Vacancies**: Characterized by offered wage, required skill, and a list of candidates.
 
The core workflow involves:
1.  Job seekers searching for vacancies through both formal (direct application) and informal (social network recommendations) channels.
2.  Firms and job seekers engaging in a wage negotiation process influenced by skill match, social capital (NRI), and market conditions.
3.  Firms updating their productivity based on hiring outcomes and deciding to create or close positions.
 
## 🧪 Key Experiments & Findings
 
The model was used to test three hypotheses:
- **H2**: Individuals who use social networks in the job search process usually receive higher salaries.
- **H3**: Social network structure affects individual wage outcomes.
 
The computational experiments compared four scenarios:
- **A (Control)**: Job search without social networks.
- **B (ER)**: Job search with an Erdos-Renyi **random** network.
- **C (BA)**: Job search with a Barabasi-Albert **scale-free** network.
- **D (WS)**: Job search with a Watts-Strogatz **small-world** network.
 
**Main Finding:** The simulation results confirm that social networks lead to higher wages (H2). Crucially, the **random network (ER)** yielded the highest and most equitable average wages, while the **scale-free network (BA)** produced the highest wage inequality. This provides strong support for H3 and Granovetter's theory.
 
## 🚀 How to Run the Model
 
1.  **Prerequisites**: Ensure you have [NetLogo 6.4.0](https://ccl.northwestern.edu/netlogo/download.shtml) (or a compatible version) installed.
2.  **Download**: Clone this repository or download the `Labor-Market-SN-ABM.nlogo` file.
3.  **Open**: Launch NetLogo and open the `.nlogo` file.
4.  **Setup**: Click the `setup` button to initialize the model.
5.  **Run**: Click the `go` button to start the simulation. Use the sliders and switches on the interface to configure parameters (see below).
 
### Key Parameters
| Parameter | Description | Default Value |
| :--- | :--- | :--- |
| `num-companies` | Initial number of firms | 235 |
| `num-seekers` | Initial number of job seekers | 600 |
| `initial-vacancies` | Initial number of job openings | 200 |
| `network-type` | Type of social network to use (None, ER, BA, WS) | ER |
| `β-negotiation` | Weight of the firm's initial offer in final wage | 0.5 |
| `skill-weight-σ` | Adjusts the impact of skill match on competence | 0.55 |
 
## 📊 Output and Data Analysis
 
The model can be run using NetLogo's **BehaviorSpace** tool to perform batch experiments. The main output metrics include:
- `mean wage`: The average wage of all employed seekers.
- `wage variance`: The variance of wages, measuring inequality.
- `employment-rate`: The percentage of seekers who are employed.
 
The resulting data can be exported as a `.csv` file for statistical analysis. An example R script for analyzing the output is provided in the `data/` directory (`analysis-script.R`).
