
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

function distances(x::Vector{Any}, y::Vector{Any},w::Tuple{Int64, Int64})
    n=size(x, 1)

    d = zeros(Int64, n, n)
    d_war= zeros(Int64, n)
    for i in 1:n
        d_war[i]=round(sqrt((w[1] - x[i])^2 + (w[2] - y[i])^2))
        for j in 1:n
            d[i, j] = round(sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2))
        end
    end
    
    return d, d_war
end

function LBBF(n::Int64,k::Int64, nbp::Vector{Any}, capa::Vector{Any}, 
    ideal::Vector{Any},x::Vector{Any}, y::Vector{Any},w::Tuple{Int64, Int64})

    d ,d_war= distances(x,y,w)
    wight = n * maximum(d)

	m = Model(Cbc.Optimizer)

	# Varibales definition 
    @variable(m, x[i in 1:n, j in 1:n], Bin)
    @variable(m, y[i=1:n, j=1:n-1, k=1:n], Bin)
    @variable(m, load[j in 0:n], Int)
    @variable(m, drop[i in 1:n, j in 1:n], Int)
    @variable(m, imbalance[i in 1:n], Int)
    
    # Constraints definition 
    @constraint(m, c1[i in 1:n], sum(x[i,j] for j in 1:n) == 1)
    @constraint(m, c2[j in 1:n], sum(x[i,j] for i in 1:n) == 1)
    @constraint(m, c3[j in 0:n], load[j] <= k )
    @constraint(m, c4[j in 1:n], load[j] == load[j-1]-sum(drop[i,j] for i in 1:n))
    @constraint(m, c5[i in 1:n,j in 1:n], drop[i,j] <= (capa[i] - nbp[i]) * x[i,j])
    @constraint(m, c6[i in 1:n,j in 1:n], -nbp[i] * x[i,j]  <= drop[i,j])
    @constraint(m, c7[i in 1:n], nbp[i] + sum(drop[i,j] for j in 1:n) - ideal[i] <= imbalance[i])
    @constraint(m, c8[i in 1:n], -nbp[i] - sum(drop[i,j] for j in 1:n) + ideal[i] <= imbalance[i])
    @constraint(m, c9[i in 1:n, j in 1:n-1, k in 1:n], y[i,j,k] >= x[i,j] + x[k,j+1] - 1)
    @constraint(m, c10[j in 0:n], load[j] >= 0)
    @constraint(m, c11[i in 1:n], imbalance[i] >= 0)
    @constraint(m, c12[i in 1:n, j in 1:n-1, k in 1:n], y[i,j,k] >= 0)
    # Objective function
    @objective(m, Min, wight * sum(imbalance[i] for i in 1:n) + sum(d_war[i] * x[i,1] for i in 1:n) + 
    sum(d_war[i] * x[i,n] for i in 1:n) + sum(sum(sum(d[i,k] * y[i,j,k] for k in 1:n) for i in 1:n) for j in 1:n-1))

    # Start chronometer
    start = time()

    # Less talking, more doing
	#set_silent(m) 

    # Solve the model
    optimize!(m)

    # Finish chronometer
    finish = time()

    #OBJ is the minimized value
    OBJ = objective_value(m)
	sum_imbalance = 0
   for i in 1:n
      sum_imbalance += JuMP.value(imbalance[i])
   end
   
    sum_imbalance=Int(trunc(sum_imbalance))
    sum_distance= Int(trunc((OBJ - wight * sum_imbalance)))
    load0=JuMP.value(load[0])
    load0=Int(trunc(load0))
    println("We took ",finish-start," seconds to finish.")
    println("The optimization resulted in an overall imbalance of: ", sum_imbalance)
    println("Total distance of: ", sum_distance)
    println("We start our tour with load 0 = ", load0)
	
	for j in 1:n
		for i in 1:n
			xij = JuMP.value(x[i,j])
			if (xij >= 0.99 && xij <= 1.01)
                dropij=round(JuMP.value(drop[i,j]))
                dropij=Int(trunc(dropij))
                println("At step $j we go to station $i, we drop $dropij")
			end
		end
	end

	
	#println(m)
	
    # Open the file and write the header
    file = open("mini_2.sol", "w")
    write(file, "name tsdp_2_s12_k11\n")
    write(file, "imbalance $sum_imbalance\n")
    write(file, "distance $sum_distance\n")
    write(file, "init_load $load0\n")

    # Write the station header
    write(file, "stations\n")

    # 
    for j in 1:n
		for i in 1:n
			xij = JuMP.value(x[i,j])
			if (xij >= 0.99 && xij <= 1.01)
                dropij=round(JuMP.value(drop[i,j]))
                dropij=Int(trunc(dropij))
                write(file, "$i  $dropij\n")
                
        
			end
		end
	end
    

    # Write the end marker
    write(file, "End\n")

    # Close the file
    close(file)
	
	# Getting the status of the solution
	status = termination_status(m)
	isOptimal = status == MOI.OPTIMAL # true if the problem has been optimally solved

	if isOptimal println("The problem was solved to the optimum")
	else println("The problem wasn't solved to the optimum")
	end
	
end



	



