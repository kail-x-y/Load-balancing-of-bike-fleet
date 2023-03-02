
#Author: Wissem Ben Marzouk

using JuMP
using Cbc

function parse_file(filename::String)
    # Open the file and read all lines
    if isfile(filename)
     file = open(filename)
     lines = readlines(file)
     
     # Initialize variables to store information
     n=0
     k = 0
     x = []
     y = []
     nbp = []
     capa = []
     ideal = []
     warehouse = (0, 0)
    
     # Parse each line
     for line in lines
        
        # Check if the line starts with "K"
        if startswith(line, "K")
            # Parse the number after "K" as the capacity of the trailer
            k = parse(Int64, split(line)[2])
        elseif startswith(line, "stations")
            # do nothing and break "if" so that this line doesn't get included in "else" condition
        elseif startswith(line, "name")
             # do nothing and break "if" so that this line doesn't get included in "else" condition
        elseif startswith(line, "#")
             # do nothing and break "if" so that this line doesn't get included in "else" condition
        elseif startswith(line, "warehouse")
            # Parse the line as the warehouse coordinates
            coords = split(line)[2:3]
            warehouse = (parse(Int64, coords[1]), parse(Int64, coords[2]))
        else
            
            tab = split(line, " ")
            push!(x, parse(Int64, tab[2]))
            push!(y, parse(Int64, tab[3]))
            push!(nbp, parse(Int64, tab[4]))
            push!(capa, parse(Int64, tab[5]))
            push!(ideal, parse(Int64, tab[6]))
            
        end
     end
     n=size(x, 1)

     # Close the file
     close(file)

     # Return the parsed information
    
    end
     return n, k, warehouse, x, y, nbp, capa, ideal
end


function LBBF_Relaxed(n::Int64,k::Int64, nbp::Vector{Any}, capa::Vector{Any}, 
    ideal::Vector{Any})



	m = Model(Cbc.Optimizer)

	#varibales definition 

    @variable(m, x[i in 1:n, j in 1:n],Bin)
    @variable(m, load[j in 0:n], Int)
    @variable(m, drop[i in 1:n, j in 1:n],Int)
    @variable(m, imbalance[i in 1:n], Int)

    #constraints definition 
    @constraint(m, c1[i in 1:n], sum(x[i,j] for j in 1:n) == 1)
    @constraint(m, c2[j in 1:n], sum(x[i,j] for i in 1:n) == 1)
    @constraint(m, c3[j in 0:n], load[j] <= k )
    @constraint(m, c4[j in 1:n], load[j] == load[j-1]-sum(drop[i,j] for i in 1:n))
    @constraint(m, c5[i in 1:n,j in 1:n], drop[i,j] <= (capa[i] - nbp[i]) * x[i,j])
    @constraint(m, c6[i in 1:n,j in 1:n], -nbp[i] * x[i,j]  <= drop[i,j])
    @constraint(m, c7[i in 1:n], nbp[i] + sum(drop[i,j] for j in 1:n) - ideal[i] <= imbalance[i])
    @constraint(m, c8[i in 1:n], -nbp[i] - sum(drop[i,j] for j in 1:n) + ideal[i] <= imbalance[i])
    @constraint(m, c10[j in 0:n], load[j] >= 0)
    @constraint(m, c11[i in 1:n], imbalance[i] >= 0)
    
    
    #objective function
    @objective(m, Min, sum(imbalance[i] for i in 1:n))

    #start chronometer
    start = time()

    #less talking, more doing
	set_silent(m)

    #relax integrality 
    relax_integrality(m);

    

    #solve the model 
    optimize!(m)

    #finish chronometer
    finish = time()

    #lower bound for imbalance is the minimized value

    lower_bound_imbalance = round(objective_value(m))

    println("We took ", finish-start, " seconds to finish.")
    println("The lower bound for imbalance : ", lower_bound_imbalance)
    # Getting the status of the solution
	status = termination_status(m)
	isOptimal = status == MOI.OPTIMAL # true if the problem has been optimally solved

	if isOptimal println("The problem was solved to the optimum.")
	else println("The problem wasn't solved to the optimum.")
	end
    
end

	



